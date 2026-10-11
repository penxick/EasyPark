const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { JwtService } = require('@nestjs/jwt');
const { DataSource, In } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const { User } = require('../../dist/users/user.entity');
const {
  AdminAnalyticsService,
} = require('../../dist/admin/admin-analytics.service');

test(
  'ADMIN analytics real PostgreSQL aggregates',
  { timeout: 90000 },
  async (t) => {
    const app = await NestFactory.create(AppModule, {
      logger: false,
      abortOnError: false,
    });
    const db = app.get(DataSource),
      users = [];
    const schema = `a6_${randomUUID().replaceAll('-', '')}`;
    let isolated;
    const tables = ['users', 'parkings', 'parking_spaces', 'reservations'];
    try {
      configureApp(app);
      await app.listen(0, '127.0.0.1');
      for (const role of ['ADMIN', 'USER'])
        users.push(
          await db.getRepository(User).save({
            name: 'A6 test',
            email: `${randomUUID()}@example.com`,
            passwordHash: 'not-for-login',
            role,
          }),
        );
      const [admin, user] = users.map((u) =>
        app.get(JwtService).sign({ sub: String(u.id) }),
      );
      const base = `${await app.getUrl()}/api/admin/analytics`;
      await t.test(
        'both HTTP endpoints enforce 401/403 and validate pagination',
        async () => {
          for (const suffix of ['', '/parkings']) {
            assert.equal((await fetch(base + suffix)).status, 401);
            assert.equal(
              (
                await fetch(base + suffix, {
                  headers: { Authorization: `Bearer ${user}` },
                })
              ).status,
              403,
            );
            const response = await fetch(base + suffix, {
              headers: { Authorization: `Bearer ${admin}` },
            });
            assert.equal(response.status, 200);
            assert.equal(response.headers.get('cache-control'), 'no-store');
            const text = JSON.stringify(await response.json());
            assert.equal(text.includes('password'), false);
            assert.equal(text.includes('email'), false);
          }
          for (const query of [
            'page=0',
            'pageSize=101',
            'page=1.5',
            'page=1&page=2',
            'unknown=1',
          ]) {
            assert.equal(
              (
                await fetch(base + '/parkings?' + query, {
                  headers: { Authorization: `Bearer ${admin}` },
                })
              ).status,
              400,
            );
          }
        },
      );
      await db.query(`CREATE SCHEMA "${schema}"`);
      // Clone table definitions only, never production data. All fixture IDs are explicit.
      for (const table of tables)
        await db.query(
          `CREATE TABLE "${schema}"."${table}" (LIKE public."${table}" INCLUDING ALL)`,
        );
      isolated = new DataSource({
        ...db.options,
        entities: [],
        migrations: [],
        schema,
        extra: { ...db.options.extra, options: `-c search_path=${schema}` },
      });
      await isolated.initialize();
      const analytics = new AdminAnalyticsService(isolated);
      const page = { page: 1, pageSize: 100 };
      await t.test(
        'empty database returns zero counters, finite occupancy and empty page',
        async () => {
          const summary = await analytics.summary();
          assert.ok(Object.values(summary).every((value) => value === 0));
          assert.deepEqual(await analytics.parkings(page), {
            items: [],
            total: 0,
            page: 1,
            pageSize: 100,
            totalPages: 0,
          });
        },
      );
      for (let id = 1; id <= 3; id++)
        await isolated.query(
          'INSERT INTO users (id,name,email,"passwordHash",role) VALUES ($1,$2,$3,$4,$5)',
          [
            id,
            `User ${id}`,
            `user${id}@example.com`,
            'test-only',
            id === 1 ? 'ADMIN' : 'USER',
          ],
        );
      for (let id = 1; id <= 4; id++)
        await isolated.query(
          'INSERT INTO parkings (id,name,description,address,latitude,longitude,"pricePerHour","workingHours") VALUES ($1,$2,$3,$4,0,0,0,$5)',
          [id, `Parking ${id}`, 'Test', 'Test', '24/7'],
        );
      const slots = [
        [1, 'FREE', false],
        [1, 'FREE', true],
        [1, 'OCCUPIED', true],
        [1, 'RESERVED', true],
        [1, 'UNAVAILABLE', true],
        [2, 'FREE', false],
        [2, 'RESERVED', false],
        [2, 'UNAVAILABLE', false],
        [4, 'UNAVAILABLE', true],
      ];
      for (const [index, [parkingId, status, physical]] of slots.entries())
        await isolated.query(
          'INSERT INTO parking_spaces (id,"parkingId",code,status,"physicalOccupied",x,y,polygon) VALUES ($1,$2,$3,$4,$5,0,0,null)',
          [index + 1, parkingId, `S${index + 1}`, status, physical],
        );
      const bookings = [
        [4, 'ACTIVE', true],
        [4, 'COMPLETED', false],
        [4, 'CANCELLED', true],
        [7, 'PENDING', true],
        [2, 'ACTIVE', false],
        [6, 'PENDING', false],
      ];
      for (const [index, [spaceId, status, future]] of bookings.entries())
        await isolated.query(
          'INSERT INTO reservations (id,"userId","parkingSpaceId",status,"startTime","endTime","totalPrice") VALUES ($1,2,$2,$3,$4,$5,100)',
          [
            index + 1,
            spaceId,
            status,
            new Date(Date.now() - 7200000),
            new Date(Date.now() + (future ? 3600000 : -3600000)),
          ],
        );
      await t.test(
        'summary counts actual data, physical occupancy and live reservations without double counts',
        async () => {
          assert.deepEqual(await analytics.summary(), {
            totalSpaces: 9,
            freeSpaces: 2,
            occupiedSpaces: 2,
            reservedSpaces: 2,
            unavailableSpaces: 3,
            physicalOccupiedSpaces: 5,
            totalParkings: 4,
            totalUsers: 3,
            totalReservations: 6,
            activeReservations: 2,
            occupancyPercent: 66.67,
          });
        },
      );
      await t.test(
        'per-parking aggregates include empty/unavailable parking and do not multiply booking history',
        async () => {
          const result = await analytics.parkings(page);
          assert.deepEqual(
            result.items.map((r) => r.id),
            [1, 2, 3, 4],
          );
          assert.deepEqual(
            result.items.map((r) => r.occupancyPercent),
            [75, 50, 0, 0],
          );
          assert.deepEqual(
            result.items.map((r) => r.totalSpaces),
            [5, 3, 0, 1],
          );
          assert.deepEqual(
            result.items.map((r) => r.totalReservations),
            [4, 2, 0, 0],
          );
          assert.deepEqual(
            result.items.map((r) => r.activeReservations),
            [1, 1, 0, 0],
          );
          const summary = await analytics.summary();
          for (const key of [
            'totalSpaces',
            'freeSpaces',
            'occupiedSpaces',
            'reservedSpaces',
            'unavailableSpaces',
            'physicalOccupiedSpaces',
            'totalReservations',
            'activeReservations',
          ])
            assert.equal(
              result.items.reduce((sum, r) => sum + r[key], 0),
              summary[key],
              key,
            );
        },
      );
      await t.test(
        'pagination is stable and returns empty pages without losing total',
        async () => {
          const second = await analytics.parkings({ page: 2, pageSize: 2 });
          assert.deepEqual(
            second.items.map((r) => r.id),
            [3, 4],
          );
          assert.equal(second.total, 4);
          assert.equal(second.totalPages, 2);
          const beyond = await analytics.parkings({ page: 3, pageSize: 2 });
          assert.deepEqual(beyond.items, []);
          assert.equal(beyond.total, 4);
        },
      );
      await t.test(
        'changed data is reflected immediately and fully unavailable inventory has zero occupancy',
        async () => {
          await isolated.query(
            'UPDATE parking_spaces SET "physicalOccupied"=true WHERE id=1',
          );
          await isolated.query(
            "UPDATE reservations SET status='CANCELLED' WHERE id=1",
          );
          const changed = await analytics.summary();
          assert.equal(changed.freeSpaces, 1);
          assert.equal(changed.occupiedSpaces, 3);
          assert.equal(changed.activeReservations, 1);
          assert.equal(changed.occupancyPercent, 83.33);
          await isolated.query(
            "UPDATE parking_spaces SET status='UNAVAILABLE'",
          );
          const unavailable = await analytics.summary();
          assert.equal(unavailable.unavailableSpaces, 9);
          assert.equal(unavailable.occupancyPercent, 0);
          assert.ok(
            (await analytics.parkings(page)).items.every(
              (r) => r.occupancyPercent === 0,
            ),
          );
        },
      );
    } finally {
      if (isolated?.isInitialized) await isolated.destroy();
      for (const table of [...tables].reverse())
        await db.query(`DROP TABLE IF EXISTS "${schema}"."${table}"`);
      await db.query(`DROP SCHEMA IF EXISTS "${schema}"`);
      if (users.length)
        await db.getRepository(User).delete({ id: In(users.map((u) => u.id)) });
      await app.close();
    }
  },
);
