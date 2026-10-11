const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { JwtService } = require('@nestjs/jwt');
const { DataSource } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const { Parking } = require('../../dist/parking/parking.entity');
const {
  ParkingSpace,
} = require('../../dist/parking-spaces/parking-space.entity');
const { User } = require('../../dist/users/user.entity');
const {
  demoParkings,
  seedParkings,
} = require('../../dist/database/parking-seed');
const { seedParkingSpaces } = require('../../dist/database/parking-space-seed');
const {
  CreateParkings1790380800000,
} = require('../../dist/database/migrations/1790380800000-create-parkings');
const {
  CreateParkingSpaces1790553600000,
} = require('../../dist/database/migrations/1790553600000-create-parking-spaces');

test(
  'ParkingSpace API and database invariants',
  { timeout: 60000 },
  async (t) => {
    const app = await NestFactory.create(AppModule, {
      logger: false,
      abortOnError: false,
    });
    const db = app.get(DataSource);
    const owned = [];
    let user;
    try {
      configureApp(app);
      await app.listen(0, '127.0.0.1');
      const base = `${await app.getUrl()}/api/parkings`;
      const parks = db.getRepository(Parking),
        spaces = db.getRepository(ParkingSpace);
      user = await db.getRepository(User).save({
        name: 'Space test',
        email: `stage10-${randomUUID()}@example.com`,
        passwordHash: 'not-for-login',
      });
      const headers = {
        Authorization: `Bearer ${app.get(JwtService).sign({ sub: String(user.id) })}`,
      };
      for (let i = 0; i < 2; i++)
        owned.push(
          await parks.save({
            ...demoParkings[0],
            name: `Space test ${randomUUID()}`,
          }),
        );
      const parking = owned[0],
        other = owned[1];
      const makeSpace = (patch = {}) => ({
        parkingId: parking.id,
        code: 'A01',
        x: 50,
        y: 50,
        ...patch,
      });
      for (const [i, status] of [
        'FREE',
        'OCCUPIED',
        'RESERVED',
        'UNAVAILABLE',
        'FREE',
      ].entries()) {
        await spaces.save(
          makeSpace({
            code: `A0${i + 1}`,
            status,
            physicalOccupied: status === 'OCCUPIED' || i === 4,
          }),
        );
      }
      await t.test(
        'JWT, contract, sorting, parent isolation, empty/invalid/missing parent',
        async () => {
          assert.equal(
            (await fetch(`${base}/${parking.id}/spaces`)).status,
            401,
          );
          const response = await fetch(`${base}/${parking.id}/spaces`, {
            headers,
          });
          assert.equal(response.status, 200);
          const items = await response.json();
          assert.equal(items.length, 5);
          assert.deepEqual(
            items.map((s) => s.code),
            ['A01', 'A02', 'A03', 'A04', 'A05'],
          );
          assert.deepEqual(
            Object.keys(items[0]).sort(),
            [
              'id',
              'parkingId',
              'code',
              'status',
              'physicalOccupied',
              'hasActiveReservation',
              'x',
              'y',
              'polygon',
              'createdAt',
              'updatedAt',
            ].sort(),
          );
          assert.ok(
            items.every(
              (s) =>
                s.parkingId === parking.id &&
                typeof s.physicalOccupied === 'boolean',
            ),
          );
          assert.equal(items[0].polygon, null);
          assert.equal(items[0].x, 50);
          const empty = await fetch(`${base}/${other.id}/spaces`, { headers });
          assert.equal(empty.status, 200);
          assert.deepEqual(await empty.json(), []);
          for (const id of ['0', '-1', 'abc', '1.5', '2147483648'])
            assert.equal(
              (await fetch(`${base}/${id}/spaces`, { headers })).status,
              400,
            );
          assert.equal(
            (await fetch(`${base}/2147483647/spaces`, { headers })).status,
            404,
          );
          assert.equal(
            (
              await fetch(`${base}/${parking.id}/spaces`, {
                headers,
                method: 'POST',
              })
            ).status,
            404,
          );
        },
      );
      await t.test(
        'counts follow status and physical occupancy without storing counters',
        async () => {
          const detail = await (
            await fetch(`${base}/${parking.id}`, { headers })
          ).json();
          assert.equal(detail.totalSpaces, 5);
          assert.equal(detail.freeSpaces, 1);
          const empty = await (
            await fetch(`${base}/${other.id}`, { headers })
          ).json();
          assert.equal(empty.totalSpaces, 0);
          assert.equal(empty.freeSpaces, 0);
          await spaces.update(
            { parkingId: parking.id, code: 'A01' },
            { status: 'RESERVED' },
          );
          const list = await (await fetch(base, { headers })).json();
          assert.equal(list.find((p) => p.id === parking.id).freeSpaces, 0);
        },
      );
      await t.test(
        'unique per parking, foreign key, status, coordinates and polygon constraints',
        async () => {
          const fails = async (patch, code) =>
            assert.rejects(
              spaces.save(makeSpace(patch)),
              (e) => e.driverError.code === code,
            );
          await fails({}, '23505');
          await spaces.save(makeSpace({ parkingId: other.id }));
          await fails({ parkingId: 2147483647 }, '23503');
          await fails({ code: 'X01', status: 'INVALID' }, '23514');
          await fails({ code: ' ' }, '23514');
          await fails({ code: 'X01', x: -1 }, '23514');
          await fails({ code: 'X01', y: Infinity }, '23514');
          await fails({ code: 'X01', x: NaN }, '23514');
          await fails({ code: 'X01', polygon: [] }, '23514');
          await spaces.save(
            makeSpace({
              code: 'X01',
              polygon: [
                [0, 0],
                [10, 0],
                [10, 10],
                [0, 10],
              ],
            }),
          );
          await assert.rejects(
            parks.delete(parking.id),
            (e) => e.driverError.code === '23503',
          );
        },
      );
      await t.test(
        'schema parity, reversible migration, concurrent seed and preservation of changes',
        async () => {
          assert.deepEqual(
            (await db.driver.createSchemaBuilder().log()).upQueries,
            [],
          );
          const schema = `stage10_${randomUUID().replaceAll('-', '')}`;
          const runner = db.createQueryRunner();
          await runner.connect();
          let isolated;
          try {
            await runner.query(`CREATE SCHEMA "${schema}"`);
            await runner.query(`SET search_path TO "${schema}"`);
            await new CreateParkings1790380800000().up(runner);
            const migration = new CreateParkingSpaces1790553600000();
            await migration.up(runner);
            isolated = new DataSource({
              ...db.options,
              schema,
              entities: [Parking, ParkingSpace],
              migrations: [],
              synchronize: false,
            });
            await isolated.initialize();
            await seedParkings(isolated);
            const inserted = await Promise.all([
              seedParkingSpaces(isolated),
              seedParkingSpaces(isolated),
            ]);
            assert.equal(
              inserted.reduce((a, b) => a + b),
              60,
            );
            const repo = isolated.getRepository(ParkingSpace);
            assert.equal(await repo.count(), 60);
            const first = await repo.findOneByOrFail({ code: 'A01' });
            await repo.update(first.id, { status: 'UNAVAILABLE', x: 99 });
            assert.equal(await seedParkingSpaces(isolated), 0);
            const preserved = await repo.findOneByOrFail({ id: first.id });
            assert.equal(preserved.status, 'UNAVAILABLE');
            assert.equal(preserved.x, 99);
            await isolated.destroy();
            isolated = undefined;
            await migration.down(runner);
            const tables = await runner.query(
              'SELECT table_name FROM information_schema.tables WHERE table_schema=$1',
              [schema],
            );
            assert.deepEqual(
              tables.map((r) => r.table_name),
              ['parkings'],
            );
            await migration.up(runner);
            await migration.down(runner);
          } finally {
            if (isolated?.isInitialized) await isolated.destroy();
            await runner.query(
              `DROP TABLE IF EXISTS "${schema}"."parking_spaces"`,
            );
            await runner.query(`DROP TABLE IF EXISTS "${schema}"."parkings"`);
            await runner.query('SET search_path TO public');
            await runner.query(`DROP SCHEMA "${schema}"`);
            await runner.release();
          }
        },
      );
    } finally {
      for (const parking of owned) {
        await db.getRepository(ParkingSpace).delete({ parkingId: parking.id });
        await db.getRepository(Parking).delete(parking.id);
      }
      if (user) await db.getRepository(User).delete(user.id);
      await app.close();
    }
  },
);
