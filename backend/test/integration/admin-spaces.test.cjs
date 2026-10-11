const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { JwtService } = require('@nestjs/jwt');
const { DataSource, In } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const { User } = require('../../dist/users/user.entity');
const { Parking } = require('../../dist/parking/parking.entity');
const {
  ParkingSpace,
} = require('../../dist/parking-spaces/parking-space.entity');
const { Reservation } = require('../../dist/reservations/reservation.entity');

test('ADMIN ParkingSpace lifecycle', { timeout: 90000 }, async (t) => {
  const app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  const db = app.get(DataSource),
    users = [],
    parks = [];
  try {
    configureApp(app);
    await app.listen(0, '127.0.0.1');
    const base = `${await app.getUrl()}/api`;
    for (const role of ['ADMIN', 'USER'])
      users.push(
        await db.getRepository(User).save({
          name: 'A4 test',
          email: `${randomUUID()}@example.com`,
          role,
          passwordHash: 'not-for-login',
        }),
      );
    for (let i = 0; i < 2; i++)
      parks.push(
        await db.getRepository(Parking).save({
          name: 'A4 test',
          description: 'Test',
          address: 'Test',
          latitude: 0,
          longitude: 0,
          pricePerHour: 100,
          workingHours: '24/7',
        }),
      );
    const [admin, user] = users.map((u) =>
      app.get(JwtService).sign({ sub: String(u.id) }),
    );
    const request = async (method, path, body, token = admin) => {
      const r = await fetch(base + path, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      return {
        status: r.status,
        body: r.status === 204 ? null : await r.json(),
      };
    };
    const polygon = [
      [0, 0],
      [10, 0],
      [10, 10],
    ];
    const payload = { code: ' A01 ', x: 1, y: 2, polygon };
    const path = `/admin/parkings/${parks[0].id}/spaces`;
    let serial = 0;
    const create = async (patch = {}, parking = parks[0]) => {
      const r = await request('POST', `/admin/parkings/${parking.id}/spaces`, {
        ...payload,
        code: `S${++serial}`,
        ...patch,
      });
      assert.equal(r.status, 201);
      return r.body;
    };
    const update = (id, body) => request('PATCH', `/admin/spaces/${id}`, body);
    const remove = (id) => request('DELETE', `/admin/spaces/${id}`);
    const book = (id) =>
      request(
        'POST',
        '/reservations',
        { parkingSpaceId: id, durationMinutes: 60 },
        user,
      );
    const get = (id) => db.getRepository(ParkingSpace).findOneByOrFail({ id });
    const read = async (id) =>
      (
        await request('GET', `/parkings/${parks[0].id}/spaces`, undefined, user)
      ).body.find((s) => s.id === id);
    const first = await create({ code: ' A01 ' });

    await t.test(
      'JWT and role protect every operation; new FREE space is visible to USER',
      async () => {
        for (const [method, route, body] of [
          ['POST', path, payload],
          ['PATCH', `/admin/spaces/${first.id}`, { code: 'Other' }],
          ['DELETE', `/admin/spaces/${first.id}`, undefined],
        ]) {
          assert.equal((await request(method, route, body, null)).status, 401);
          assert.equal((await request(method, route, body, user)).status, 403);
        }
        assert.equal(first.code, 'A01');
        assert.equal(first.status, 'FREE');
        assert.equal(first.physicalOccupied, false);
        assert.equal(first.hasActiveReservation, false);
        assert.deepEqual((await read(first.id)).polygon, polygon);
        assert.equal(
          (await request('GET', `/parkings/${parks[0].id}`, undefined, user))
            .body.freeSpaces,
          1,
        );
      },
    );
    await t.test(
      'DTO rejects bad geometry, empty fields, status/physical overrides and invalid identifiers',
      async () => {
        for (const key of Object.keys(payload)) {
          const missing = { ...payload };
          delete missing[key];
          assert.equal((await request('POST', path, missing)).status, 400, key);
        }
        for (const body of [
          { code: '' },
          { code: '   ' },
          { code: 'a'.repeat(21) },
          { code: null },
          { x: -1 },
          { y: -1 },
          { x: '1' },
          { y: null },
          { polygon: [] },
          {
            polygon: [
              [0, 0],
              [1, 1],
            ],
          },
          { polygon: [[0, 0], [1, 1], [2]] },
          {
            polygon: [
              [0, 0],
              [1, 1],
              ['2', 2],
            ],
          },
          {
            polygon: [
              [0, 0],
              [1, 1],
              [null, 2],
            ],
          },
          { polygon: Array(1001).fill([0, 0]) },
          { polygon: 'bad' },
          { physicalOccupied: true },
          { status: 'FREE' },
          { parkingId: parks[1].id },
          { id: first.id },
        ]) {
          assert.equal(
            (await request('POST', path, { ...payload, ...body })).status,
            400,
          );
          assert.equal((await update(first.id, body)).status, 400);
        }
        for (const available of [null, 'false', 0])
          assert.equal((await update(first.id, { available })).status, 400);
        assert.equal((await update(first.id, {})).status, 400);
        assert.equal(
          (await request('POST', path, { ...payload, available: false }))
            .status,
          400,
        );
        for (const id of ['0', '-1', 'bad', '1.5', '2147483648']) {
          assert.equal((await update(id, { x: 1 })).status, 400);
          assert.equal((await remove(id)).status, 400);
          assert.equal(
            (await request('POST', `/admin/parkings/${id}/spaces`, payload))
              .status,
            400,
          );
        }
        assert.equal((await update(2147483647, { x: 1 })).status, 404);
        assert.equal((await remove(2147483647)).status, 404);
        assert.equal(
          (await request('POST', '/admin/parkings/2147483647/spaces', payload))
            .status,
          404,
        );
      },
    );
    await t.test(
      'code is unique per parking, including concurrent create and conflicting edit',
      async () => {
        const duplicates = await Promise.all([
          request('POST', path, { ...payload, code: 'RACE' }),
          request('POST', path, { ...payload, code: 'RACE' }),
        ]);
        assert.deepEqual(duplicates.map((r) => r.status).sort(), [201, 409]);
        assert.equal(
          duplicates.find((r) => r.status === 409).body.code,
          'SPACE_CODE_EXISTS',
        );
        await create({ code: 'A01' }, parks[1]);
        const second = await create();
        assert.equal(
          (await update(second.id, { code: 'A01', x: 99 })).status,
          409,
        );
        assert.equal((await get(second.id)).x, 1);
      },
    );
    await t.test(
      'geometry edits preserve physical occupancy and omitted polygon',
      async () => {
        await db
          .getRepository(ParkingSpace)
          .update(first.id, { physicalOccupied: true, status: 'OCCUPIED' });
        const edited = await update(first.id, { code: 'B01', x: 0, y: 25 });
        assert.equal(edited.status, 200);
        assert.equal(edited.body.physicalOccupied, true);
        assert.deepEqual(edited.body.polygon, polygon);
        assert.equal(edited.body.status, 'OCCUPIED');
        const replacement = [
          [-1, -1],
          [4, 0],
          [0, 4],
        ];
        assert.deepEqual(
          (await update(first.id, { polygon: replacement })).body.polygon,
          replacement,
        );
        assert.equal(
          (await update(first.id, { polygon: null })).body.polygon,
          null,
        );
        assert.equal(
          (await update(first.id, { available: false })).body.status,
          'UNAVAILABLE',
        );
        const enabled = await update(first.id, { available: true });
        assert.equal(enabled.body.status, 'OCCUPIED');
        assert.equal(enabled.body.physicalOccupied, true);
        assert.equal((await book(first.id)).status, 409);
      },
    );
    await t.test(
      'disable blocks booking; enable derives FREE or RESERVED without cancelling live reservation',
      async () => {
        const s = await create({ polygon: null });
        assert.equal(
          (await update(s.id, { available: false })).body.status,
          'UNAVAILABLE',
        );
        assert.equal((await book(s.id)).status, 409);
        assert.equal(
          (await update(s.id, { available: true })).body.status,
          'FREE',
        );
        const booking = await book(s.id);
        assert.equal(booking.status, 201);
        const disabled = await update(s.id, { available: false });
        assert.equal(disabled.body.status, 'UNAVAILABLE');
        assert.equal(disabled.body.hasActiveReservation, true);
        assert.equal((await read(s.id)).hasActiveReservation, true);
        assert.equal(
          (
            await db
              .getRepository(Reservation)
              .findOneByOrFail({ id: booking.body.id })
          ).status,
          'ACTIVE',
        );
        assert.equal(
          (await update(s.id, { available: true })).body.status,
          'RESERVED',
        );
        await update(s.id, { available: false });
        assert.equal(
          (
            await request(
              'PATCH',
              `/reservations/${booking.body.id}/cancel`,
              undefined,
              user,
            )
          ).status,
          200,
        );
        assert.equal((await get(s.id)).status, 'UNAVAILABLE');
        assert.equal(
          (await update(s.id, { available: true })).body.status,
          'FREE',
        );
        assert.equal((await read(s.id)).hasActiveReservation, false);
      },
    );
    await t.test(
      'reenabling expires stale ACTIVE/PENDING bookings through existing reservation logic',
      async () => {
        for (const [oldStatus, endStatus] of [
          ['ACTIVE', 'COMPLETED'],
          ['PENDING', 'EXPIRED'],
        ]) {
          const s = await create();
          const b = await book(s.id);
          assert.equal(b.status, 201);
          await update(s.id, { available: false });
          await db.getRepository(Reservation).update(b.body.id, {
            status: oldStatus,
            startTime: new Date(Date.now() - 120000),
            endTime: new Date(Date.now() - 60000),
          });
          assert.equal((await read(s.id)).hasActiveReservation, false);
          const enabled = await update(s.id, { available: true });
          assert.equal(enabled.body.status, 'FREE');
          assert.equal(enabled.body.hasActiveReservation, false);
          assert.equal(
            (
              await db
                .getRepository(Reservation)
                .findOneByOrFail({ id: b.body.id })
            ).status,
            endStatus,
          );
        }
      },
    );
    await t.test(
      'deletion preserves every historical status and removes only unbooked spaces',
      async () => {
        const s = await create();
        const b = await book(s.id);
        assert.equal(b.status, 201);
        for (const status of [
          'ACTIVE',
          'PENDING',
          'COMPLETED',
          'CANCELLED',
          'EXPIRED',
        ]) {
          await db.getRepository(Reservation).update(b.body.id, { status });
          const r = await remove(s.id);
          assert.equal(r.status, 409);
          assert.equal(r.body.code, 'SPACE_HAS_RESERVATIONS');
          assert.equal((await get(s.id)).id, s.id);
        }
        const free = await create();
        assert.equal((await remove(free.id)).status, 204);
        assert.equal((await remove(free.id)).status, 404);
      },
    );
    await t.test(
      'concurrent booking with disable or delete preserves consistency',
      async () => {
        for (const action of ['disable', 'delete']) {
          for (let i = 0; i < 3; i++) {
            const s = await create();
            const [b, mutation] = await Promise.all([
              book(s.id),
              action === 'disable'
                ? update(s.id, { available: false })
                : remove(s.id),
            ]);
            if (action === 'disable') {
              assert.equal(mutation.status, 200);
              assert.ok([201, 409].includes(b.status));
              assert.equal((await get(s.id)).status, 'UNAVAILABLE');
            } else if (b.status === 201) {
              assert.equal(mutation.status, 409);
            } else {
              assert.equal(b.status, 404);
              assert.equal(mutation.status, 204);
            }
            if (b.status === 201)
              assert.equal(
                await db.getRepository(Reservation).existsBy({ id: b.body.id }),
                true,
              );
          }
        }
      },
    );
  } finally {
    if (parks.length) {
      const spaces = await db
        .getRepository(ParkingSpace)
        .findBy({ parkingId: In(parks.map((p) => p.id)) });
      if (spaces.length)
        await db
          .getRepository(Reservation)
          .delete({ parkingSpaceId: In(spaces.map((s) => s.id)) });
      await db
        .getRepository(ParkingSpace)
        .delete({ parkingId: In(parks.map((p) => p.id)) });
      await db
        .getRepository(Parking)
        .delete({ id: In(parks.map((p) => p.id)) });
    }
    if (users.length)
      await db.getRepository(User).delete({ id: In(users.map((u) => u.id)) });
    await app.close();
  }
});
