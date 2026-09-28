const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { JwtService } = require('@nestjs/jwt');
const { DataSource } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const { Parking } = require('../../dist/parking/parking.entity');
const { User } = require('../../dist/users/user.entity');
const {
  seedParkings,
  demoParkings,
} = require('../../dist/database/parking-seed');
const {
  CreateParkings1790380800000,
} = require('../../dist/database/migrations/1790380800000-create-parkings');

test(
  'Parking API, migration and seed with PostgreSQL',
  { timeout: 60000 },
  async (t) => {
    const app = await NestFactory.create(AppModule, {
      logger: false,
      abortOnError: false,
    });
    const db = app.get(DataSource);
    let user, parking;
    try {
      configureApp(app);
      await app.listen(0, '127.0.0.1');
      const base = `${await app.getUrl()}/api/parkings`;
      user = await db.getRepository(User).save({
        name: 'Parking test',
        email: `stage7-${randomUUID()}@example.com`,
        passwordHash: 'not-a-login-hash',
      });
      const token = app.get(JwtService).sign({ sub: String(user.id) });
      const headers = { Authorization: `Bearer ${token}` };
      parking = await db.getRepository(Parking).save({
        ...demoParkings[0],
        name: `Test ${randomUUID()}`,
        pricePerHour: 123.45,
      });
      await t.test(
        'list/detail contract, authentication, invalid and missing IDs',
        async () => {
          assert.equal((await fetch(base)).status, 401);
          assert.equal((await fetch(`${base}/${parking.id}`)).status, 401);
          const response = await fetch(base, { headers });
          assert.equal(response.status, 200);
          const list = await response.json();
          assert.deepEqual(
            list.map((p) => p.id),
            list.map((p) => p.id).sort((a, b) => a - b),
          );
          const item = list.find((p) => p.id === parking.id);
          assert.deepEqual(
            Object.keys(item).sort(),
            [
              'id',
              'name',
              'description',
              'address',
              'latitude',
              'longitude',
              'pricePerHour',
              'workingHours',
              'createdAt',
              'updatedAt',
              'freeSpaces',
              'totalSpaces',
            ].sort(),
          );
          assert.equal(item.pricePerHour, 123.45);
          assert.equal(item.latitude, demoParkings[0].latitude);
          assert.equal(typeof item.longitude, 'number');
          assert.ok(Number.isFinite(Date.parse(item.createdAt)));
          const detail = await fetch(`${base}/${parking.id}`, { headers });
          assert.equal(detail.status, 200);
          assert.deepEqual(await detail.json(), item);
          for (const id of [
            '0',
            '-1',
            '1.5',
            'abc',
            '2147483648',
            '1e2',
            '99999999999999999999',
          ]) {
            assert.equal(
              (await fetch(`${base}/${id}`, { headers })).status,
              400,
              id,
            );
          }
          assert.equal(
            (await fetch(`${base}/2147483647`, { headers })).status,
            404,
          );
          assert.equal(
            (await fetch(base, { headers, method: 'POST' })).status,
            404,
          );
        },
      );
      await t.test(
        'migration parity, reversible isolated schema and concurrent idempotent seed',
        async () => {
          assert.deepEqual(
            (await db.driver.createSchemaBuilder().log()).upQueries,
            [],
          );
          const schema = `stage7_${randomUUID().replaceAll('-', '')}`;
          const runner = db.createQueryRunner();
          const migration = new CreateParkings1790380800000();
          let isolated;
          await runner.connect();
          try {
            await runner.query(`CREATE SCHEMA "${schema}"`);
            await runner.query(`SET search_path TO "${schema}"`);
            await migration.up(runner);
            isolated = new DataSource({
              ...db.options,
              schema,
              entities: [Parking],
              migrations: [],
              synchronize: false,
            });
            await isolated.initialize();
            assert.equal(await isolated.getRepository(Parking).count(), 0);
            const inserted = await Promise.all([
              seedParkings(isolated),
              seedParkings(isolated),
            ]);
            assert.equal(
              inserted.reduce((a, b) => a + b),
              3,
            );
            assert.equal(await isolated.getRepository(Parking).count(), 3);
            const first = await isolated
              .getRepository(Parking)
              .findOneByOrFail({ name: demoParkings[0].name });
            await isolated
              .getRepository(Parking)
              .update(first.id, { pricePerHour: 77 });
            assert.equal(await seedParkings(isolated), 0);
            assert.equal(
              (
                await isolated
                  .getRepository(Parking)
                  .findOneByOrFail({ id: first.id })
              ).pricePerHour,
              77,
            );
            for (const patch of [
              { latitude: 91 },
              { longitude: -181 },
              { pricePerHour: -1 },
            ]) {
              await assert.rejects(
                isolated
                  .getRepository(Parking)
                  .save({ ...demoParkings[0], ...patch }),
                (error) => error.driverError.code === '23514',
              );
            }
            await isolated.destroy();
            isolated = undefined;
            await migration.down(runner);
            assert.equal(
              (
                await runner.query(
                  'SELECT table_name FROM information_schema.tables WHERE table_schema=$1',
                  [schema],
                )
              ).length,
              0,
            );
          } finally {
            if (isolated?.isInitialized) await isolated.destroy();
            // Only this randomly named test schema; never public data.
            await runner.query(`DROP TABLE IF EXISTS "${schema}"."parkings"`);
            await runner.query('SET search_path TO public');
            await runner.query(`DROP SCHEMA "${schema}"`);
            await runner.release();
          }
        },
      );
    } finally {
      if (parking) await db.getRepository(Parking).delete(parking.id);
      if (user) await db.getRepository(User).delete(user.id);
      await app.close();
    }
  },
);
