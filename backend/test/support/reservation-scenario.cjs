const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { In } = require('typeorm');
const { User } = require('../../dist/users/user.entity');
const { Parking } = require('../../dist/parking/parking.entity');
const {
  ParkingSpace,
} = require('../../dist/parking-spaces/parking-space.entity');
const { Reservation } = require('../../dist/reservations/reservation.entity');
const { demoParkings } = require('../../dist/database/parking-seed');

async function reservationScenario({
  db,
  base,
  jwt,
  service,
  test,
  waitForWorker = false,
}) {
  const users = [],
    spaces = [];
  let parking;
  const repo = db.getRepository(Reservation),
    spaceRepo = db.getRepository(ParkingSpace);
  try {
    for (let i = 0; i < 2; i++)
      users.push(
        await db.getRepository(User).save({
          name: 'Reservation test',
          email: `stage12-${randomUUID()}@example.com`,
          passwordHash: 'not-for-login',
        }),
      );
    parking = await db.getRepository(Parking).save({
      ...demoParkings[0],
      name: `Reservation test ${randomUUID()}`,
      pricePerHour: 120.51,
    });
    for (let i = 0; i < 10; i++)
      spaces.push(
        await spaceRepo.save({
          parkingId: parking.id,
          code: `T${i}`,
          x: 50,
          y: 50,
        }),
      );
    const request = async (path, { user = 0, method = 'GET', body } = {}) => {
      const response = await fetch(`${base}${path}`, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(user === null
            ? {}
            : {
                Authorization: `Bearer ${jwt.sign({ sub: String(users[user].id) })}`,
              }),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      return { status: response.status, body: await response.json() };
    };
    const create = (id, user = 0, durationMinutes = 60) =>
      request('/reservations', {
        user,
        method: 'POST',
        body: { parkingSpaceId: id, durationMinutes },
      });
    const cancel = (id, user = 0) =>
      request(`/reservations/${id}/cancel`, { user, method: 'PATCH' });

    await test('JWT, strict input, missing resources and ownership', async () => {
      for (const [path, method] of [
        ['/reservations', 'POST'],
        ['/reservations/me', 'GET'],
        ['/reservations/1/cancel', 'PATCH'],
      ])
        assert.equal((await request(path, { user: null, method })).status, 401);
      for (const body of [
        {},
        { parkingSpaceId: spaces[0].id, durationMinutes: 45 },
        { parkingSpaceId: String(spaces[0].id), durationMinutes: 60 },
        { parkingSpaceId: 0, durationMinutes: 60 },
        {
          parkingSpaceId: spaces[0].id,
          durationMinutes: 60,
          userId: users[1].id,
        },
        { parkingSpaceId: spaces[0].id, durationMinutes: 60, totalPrice: 0 },
        {
          parkingSpaceId: spaces[0].id,
          durationMinutes: 60,
          startTime: new Date().toISOString(),
        },
      ])
        assert.equal(
          (await request('/reservations', { method: 'POST', body })).status,
          400,
        );
      assert.equal((await create(2147483647)).status, 404);
      for (const id of ['0', '-1', 'abc', '1.5', '2147483648'])
        assert.equal((await cancel(id)).status, 400);
      assert.equal((await cancel(2147483647)).status, 404);
      assert.deepEqual((await request('/reservations/me')).body, []);
    });
    await test('all durations, server price/time, isolated history and idempotent cancellation', async () => {
      for (const minutes of [30, 60, 120, 180]) {
        const before = Date.now();
        const result = await create(spaces[0].id, 0, minutes);
        assert.equal(result.status, 201);
        const r = result.body;
        assert.equal(r.status, 'ACTIVE');
        assert.equal(r.userId, users[0].id);
        assert.equal(r.totalPrice, Math.round((12051 * minutes) / 60) / 100);
        assert.ok(
          Date.parse(r.startTime) >= before - 1000 &&
            Date.parse(r.startTime) <= Date.now() + 1000,
        );
        assert.equal(
          Date.parse(r.endTime) - Date.parse(r.startTime),
          minutes * 60000,
        );
        assert.equal(
          (await spaceRepo.findOneByOrFail({ id: spaces[0].id })).status,
          'RESERVED',
        );
        assert.equal((await cancel(r.id, 1)).status, 404);
        assert.deepEqual(
          (await request('/reservations/me', { user: 1 })).body,
          [],
        );
        assert.equal((await cancel(r.id)).body.status, 'CANCELLED');
        assert.equal((await cancel(r.id)).body.status, 'CANCELLED');
        assert.equal(
          (await spaceRepo.findOneByOrFail({ id: spaces[0].id })).status,
          'FREE',
        );
      }
      const history = (await request('/reservations/me')).body;
      assert.equal(history.length, 4);
      assert.ok(
        history.every(
          (r) =>
            r.userId === users[0].id &&
            r.status === 'CANCELLED' &&
            !('user' in r),
        ),
      );
      assert.ok(history[0].id > history[3].id);
    });
    await test('unavailable and physically occupied spaces cannot be booked', async () => {
      for (const status of ['OCCUPIED', 'RESERVED', 'UNAVAILABLE']) {
        await spaceRepo.update(spaces[1].id, { status });
        assert.equal((await create(spaces[1].id)).status, 409);
      }
      await spaceRepo.update(spaces[1].id, {
        status: 'FREE',
        physicalOccupied: true,
      });
      assert.equal((await create(spaces[1].id)).status, 409);
      assert.equal(await repo.countBy({ parkingSpaceId: spaces[1].id }), 0);
    });
    await test('eight simultaneous requests produce exactly one reservation and accurate counts', async () => {
      const before = (await request(`/parkings/${parking.id}`)).body.freeSpaces;
      const results = await Promise.all(
        Array.from({ length: 8 }, (_, i) => create(spaces[2].id, i % 2)),
      );
      assert.equal(results.filter((r) => r.status === 201).length, 1);
      assert.equal(results.filter((r) => r.status === 409).length, 7);
      assert.equal(
        await repo.countBy({
          parkingSpaceId: spaces[2].id,
          status: In(['ACTIVE', 'PENDING']),
        }),
        1,
      );
      assert.equal(
        (await request(`/parkings/${parking.id}`)).body.freeSpaces,
        before - 1,
      );
      const winner = results.find((r) => r.status === 201).body;
      const owner = users.findIndex((u) => u.id === winner.userId);
      const cancellations = await Promise.all([
        cancel(winner.id, owner),
        cancel(winner.id, owner),
      ]);
      assert.ok(
        cancellations.every(
          (r) => r.status === 200 && r.body.status === 'CANCELLED',
        ),
      );
      assert.equal(
        (await request(`/parkings/${parking.id}`)).body.freeSpaces,
        before,
      );
    });
    await test('cancellation preserves physical occupancy and administrative closure', async () => {
      for (const [i, patch, expected] of [
        [3, { physicalOccupied: true }, 'OCCUPIED'],
        [4, { status: 'UNAVAILABLE' }, 'UNAVAILABLE'],
      ]) {
        const created = await create(spaces[i].id);
        assert.equal(created.status, 201);
        await spaceRepo.update(spaces[i].id, patch);
        assert.equal((await cancel(created.body.id)).status, 200);
        assert.equal(
          (await spaceRepo.findOneByOrFail({ id: spaces[i].id })).status,
          expected,
        );
      }
    });
    await test('expired active bookings complete, pending expire, restart catch-up and rebooking work', async () => {
      const old = async (spaceId, status = 'ACTIVE') => {
        const created = await create(spaceId);
        assert.equal(created.status, 201);
        await repo.update(created.body.id, {
          startTime: new Date(Date.now() - 7200000),
          endTime: new Date(Date.now() - 3600000),
          status,
        });
        return created.body.id;
      };
      const ended = await old(spaces[5].id);
      assert.equal((await cancel(ended)).status, 409);
      assert.equal(
        (await repo.findOneByOrFail({ id: ended })).status,
        'COMPLETED',
      );
      assert.equal(
        (await spaceRepo.findOneByOrFail({ id: spaces[5].id })).status,
        'FREE',
      );
      const pending = await old(spaces[5].id, 'PENDING');
      assert.equal((await create(spaces[5].id, 1)).status, 201);
      assert.equal(
        (await repo.findOneByOrFail({ id: pending })).status,
        'EXPIRED',
      );
      const historyEnded = await old(spaces[6].id);
      assert.equal(
        (await request('/reservations/me')).body.find(
          (r) => r.id === historyEnded,
        ).status,
        'COMPLETED',
      );
      const workerEnded = await old(spaces[7].id);
      await spaceRepo.update(spaces[7].id, { physicalOccupied: true });
      if (waitForWorker) {
        const deadline = Date.now() + 40000;
        while (
          (await repo.findOneByOrFail({ id: workerEnded })).status ===
            'ACTIVE' &&
          Date.now() < deadline
        ) {
          await new Promise((resolve) => setTimeout(resolve, 500));
        }
      } else {
        await service.expireDue();
      }
      assert.equal(
        (await repo.findOneByOrFail({ id: workerEnded })).status,
        'COMPLETED',
      );
      assert.equal(
        (await spaceRepo.findOneByOrFail({ id: spaces[7].id })).status,
        'OCCUPIED',
      );
    });
    await test('database independently rejects duplicate live bookings, invalid values and broken foreign keys', async () => {
      const values = {
        userId: users[0].id,
        parkingSpaceId: spaces[8].id,
        startTime: new Date(),
        endTime: new Date(Date.now() + 3600000),
        totalPrice: 120.51,
        status: 'PENDING',
      };
      const first = await repo.save({ ...values });
      await assert.rejects(
        repo.save({ ...values, userId: users[1].id, status: 'ACTIVE' }),
        (e) => e.driverError.code === '23505',
      );
      // The service also checks reservations if a future writer leaves a stale FREE flag.
      assert.equal((await create(spaces[8].id)).status, 409);
      await repo.update(first.id, { status: 'CANCELLED' });
      for (const [patch, code] of [
        [{ userId: 2147483647 }, '23503'],
        [{ parkingSpaceId: 2147483647 }, '23503'],
        [{ status: 'INVALID' }, '23514'],
        [{ totalPrice: -1 }, '23514'],
        [{ totalPrice: NaN }, '23514'],
        [{ endTime: values.startTime }, '23514'],
      ])
        await assert.rejects(
          repo.save({ ...values, ...patch }),
          (e) => e.driverError.code === code,
        );
      await assert.rejects(
        spaceRepo.delete(spaces[8].id),
        (e) => e.driverError.code === '23503',
      );
      await assert.rejects(
        db.getRepository(User).delete(users[0].id),
        (e) => e.driverError.code === '23503',
      );
      await repo.save({ ...values });
    });
  } finally {
    // Delete only identities and parking fixtures created by this invocation.
    for (const user of users) await repo.delete({ userId: user.id });
    if (parking) {
      await spaceRepo.delete({ parkingId: parking.id });
      await db.getRepository(Parking).delete(parking.id);
    }
    for (const user of users) await db.getRepository(User).delete(user.id);
  }
}
module.exports = { reservationScenario };
