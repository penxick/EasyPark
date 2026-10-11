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

test('ADMIN users and reservations read API', { timeout: 90000 }, async (t) => {
  const app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  const db = app.get(DataSource),
    users = [],
    spaces = [],
    reservations = [];
  let parking;
  try {
    configureApp(app);
    await app.listen(0, '127.0.0.1');
    const base = `${await app.getUrl()}/api`;
    const createdAt = new Date(Date.now() + 86400000);
    for (const role of ['ADMIN', 'USER', 'USER'])
      users.push(
        await db.getRepository(User).save({
          name: `A5 ${role}`,
          email: `${randomUUID()}@example.com`,
          role,
          passwordHash: 'a5-private-hash',
          createdAt,
        }),
      );
    const [admin, user] = users.map((u) =>
      app.get(JwtService).sign({ sub: String(u.id) }),
    );
    parking = await db.getRepository(Parking).save({
      name: 'A5 parking',
      description: 'Test',
      address: 'A5 address',
      latitude: 0,
      longitude: 0,
      pricePerHour: 100,
      workingHours: '24/7',
    });
    for (const [index, status] of [
      'ACTIVE',
      'PENDING',
      'COMPLETED',
      'EXPIRED',
      'CANCELLED',
      'ACTIVE',
      'PENDING',
    ].entries()) {
      const space = await db
        .getRepository(ParkingSpace)
        .save({ parkingId: parking.id, code: `A${index}`, x: 0, y: 0 });
      spaces.push(space);
      reservations.push(
        await db.getRepository(Reservation).save({
          userId: users[1].id,
          parkingSpaceId: space.id,
          status,
          totalPrice: 123.45,
          createdAt,
          startTime: new Date(Date.now() - 7200000),
          endTime: new Date(Date.now() + (index >= 5 ? -3600000 : 3600000)),
        }),
      );
    }
    const get = async (path, token = admin) => {
      const response = await fetch(base + path, {
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      });
      return {
        status: response.status,
        body: await response.json(),
        headers: response.headers,
      };
    };
    const safe = (body) => {
      const text = JSON.stringify(body);
      assert.equal(text.includes('passwordHash'), false);
      assert.equal(text.includes('a5-private-hash'), false);
      assert.equal(text.includes('accessToken'), false);
    };
    const routes = [
      '/admin/users',
      `/admin/users/${users[1].id}`,
      '/admin/reservations',
      `/admin/reservations/${reservations[0].id}`,
    ];
    await t.test(
      'all endpoints enforce 401/403 and safe uncached ADMIN responses',
      async () => {
        for (const route of routes) {
          assert.equal((await get(route, null)).status, 401);
          assert.equal((await get(route, user)).status, 403);
          const r = await get(route);
          assert.equal(r.status, 200);
          assert.equal(r.headers.get('cache-control'), 'no-store');
          safe(r.body);
        }
      },
    );
    await t.test(
      'strict pagination, category and IDs reject malformed or excessive queries',
      async () => {
        for (const route of [
          '/admin/users',
          '/admin/reservations',
          `/admin/users/${users[1].id}`,
        ]) {
          for (const query of [
            'page=0',
            'page=-1',
            'page=1.5',
            'page=1e2',
            'page=1000001',
            'page=',
            'page=1&page=2',
            'pageSize=101',
            'pageSize=0',
            'pageSize=null',
            'extra=1',
          ]) {
            assert.equal((await get(`${route}?${query}`)).status, 400, query);
          }
        }
        assert.equal(
          (await get('/admin/reservations?category=bogus')).status,
          400,
        );
        assert.equal((await get('/admin/users?category=active')).status, 400);
        for (const kind of ['users', 'reservations']) {
          for (const id of ['0', '-1', 'bad', '1.5', '2147483648'])
            assert.equal((await get(`/admin/${kind}/${id}`)).status, 400);
          assert.equal((await get(`/admin/${kind}/2147483647`)).status, 404);
        }
      },
    );
    await t.test(
      'users list pagination has stable ordering and explicit public fields',
      async () => {
        const one = (await get('/admin/users?pageSize=2')).body;
        const two = (await get('/admin/users?page=2&pageSize=2')).body;
        assert.equal(one.page, 1);
        assert.equal(one.pageSize, 2);
        assert.equal(one.totalPages, Math.ceil(one.total / 2));
        assert.deepEqual(
          one.items.map((u) => u.id),
          [users[2].id, users[1].id],
        );
        assert.equal(two.items[0].id, users[0].id);
        assert.deepEqual(
          Object.keys(one.items[0]).sort(),
          ['id', 'name', 'email', 'role', 'createdAt', 'updatedAt'].sort(),
        );
        assert.equal(
          (await get('/admin/users?page=1000000')).body.items.length,
          0,
        );
      },
    );
    await t.test(
      'user details return real totals and isolated paginated history, including empty user',
      async () => {
        const r = (await get(`/admin/users/${users[1].id}?pageSize=2&page=2`))
          .body;
        assert.equal(r.reservationCount, 7);
        assert.equal(r.activeReservationCount, 2);
        assert.equal(r.reservations.total, 7);
        assert.equal(r.reservations.totalPages, 4);
        assert.deepEqual(
          r.reservations.items.map((x) => x.id),
          [reservations[4].id, reservations[3].id],
        );
        assert.ok(r.reservations.items.every((x) => x.user.id === users[1].id));
        const empty = (await get(`/admin/users/${users[2].id}`)).body;
        assert.equal(empty.reservationCount, 0);
        assert.equal(empty.activeReservationCount, 0);
        assert.deepEqual(empty.reservations.items, []);
        assert.equal(empty.reservations.totalPages, 0);
        const beyond = (await get(`/admin/users/${users[1].id}?page=1000000`))
          .body;
        assert.equal(beyond.reservations.total, 7);
        assert.deepEqual(beyond.reservations.items, []);
      },
    );
    await t.test(
      'reservation categories classify live, terminal and overdue records consistently',
      async () => {
        const expected = {
          active: [0, 1],
          completed: [2, 3, 5, 6],
          cancelled: [4],
          all: [0, 1, 2, 3, 4, 5, 6],
        };
        for (const [category, indexes] of Object.entries(expected)) {
          const result = (
            await get(`/admin/reservations?category=${category}&pageSize=100`)
          ).body;
          const owned = result.items.filter((r) => r.parking.id === parking.id);
          assert.deepEqual(
            owned.map((r) => r.id).sort((a, b) => a - b),
            indexes.map((i) => reservations[i].id),
          );
          safe(result);
        }
        const one = (await get('/admin/reservations?pageSize=2')).body;
        const two = (await get('/admin/reservations?pageSize=2&page=2')).body;
        assert.deepEqual(
          one.items.map((r) => r.id),
          [reservations[6].id, reservations[5].id],
        );
        assert.deepEqual(
          two.items.map((r) => r.id),
          [reservations[4].id, reservations[3].id],
        );
        assert.equal(
          (await get('/admin/reservations?page=1000000')).body.items.length,
          0,
        );
      },
    );
    await t.test(
      'reservation detail joins identity, location, code, timestamps and numeric price',
      async () => {
        const r = (await get(`/admin/reservations/${reservations[0].id}`)).body;
        assert.deepEqual(r.user, {
          id: users[1].id,
          name: users[1].name,
          email: users[1].email,
        });
        assert.deepEqual(r.parking, {
          id: parking.id,
          name: parking.name,
          address: parking.address,
        });
        assert.deepEqual(r.space, { id: spaces[0].id, code: spaces[0].code });
        assert.equal(r.totalPrice, 123.45);
        assert.equal(r.status, 'ACTIVE');
        for (const key of ['createdAt', 'startTime', 'endTime'])
          assert.ok(Number.isFinite(Date.parse(r[key])));
        assert.equal(
          (await get(`/admin/reservations/${reservations[5].id}`)).body.status,
          'COMPLETED',
        );
        assert.equal(
          (await get(`/admin/reservations/${reservations[6].id}`)).body.status,
          'EXPIRED',
        );
        safe(r);
      },
    );
    await t.test(
      'USER history and cancellation remain scoped to their owner',
      async () => {
        const other = app.get(JwtService).sign({ sub: String(users[2].id) });
        assert.deepEqual((await get('/reservations/me', other)).body, []);
        const cancelled = await fetch(
          `${base}/reservations/${reservations[0].id}/cancel`,
          { method: 'PATCH', headers: { Authorization: `Bearer ${other}` } },
        );
        assert.equal(cancelled.status, 404);
        const mine = (await get('/reservations/me', user)).body;
        assert.equal(mine.length, 7);
        assert.ok(mine.every((r) => r.userId === users[1].id));
      },
    );
  } finally {
    if (reservations.length)
      await db
        .getRepository(Reservation)
        .delete({ id: In(reservations.map((r) => r.id)) });
    if (spaces.length)
      await db
        .getRepository(ParkingSpace)
        .delete({ id: In(spaces.map((s) => s.id)) });
    if (parking) await db.getRepository(Parking).delete(parking.id);
    if (users.length)
      await db.getRepository(User).delete({ id: In(users.map((u) => u.id)) });
    await app.close();
  }
});
