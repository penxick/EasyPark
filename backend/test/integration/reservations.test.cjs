const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { JwtService } = require('@nestjs/jwt');
const { DataSource } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const {
  ReservationsService,
} = require('../../dist/reservations/reservations.service');
const { reservationScenario } = require('../support/reservation-scenario.cjs');
const {
  CreateUsers1789776000000,
} = require('../../dist/database/migrations/1789776000000-create-users');
const {
  CreateParkings1790380800000,
} = require('../../dist/database/migrations/1790380800000-create-parkings');
const {
  CreateParkingSpaces1790553600000,
} = require('../../dist/database/migrations/1790553600000-create-parking-spaces');
const {
  CreateReservations1790640000000,
} = require('../../dist/database/migrations/1790640000000-create-reservations');

test('Reservation API and database', { timeout: 60000 }, async (t) => {
  const app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  try {
    configureApp(app);
    await app.listen(0, '127.0.0.1');
    const db = app.get(DataSource);
    await reservationScenario({
      db,
      base: `${await app.getUrl()}/api`,
      jwt: app.get(JwtService),
      service: app.get(ReservationsService),
      test: (name, fn) => t.test(name, fn),
    });
    await t.test(
      'entity schema parity and reversible migration in an isolated schema',
      async () => {
        assert.deepEqual(
          (await db.driver.createSchemaBuilder().log()).upQueries,
          [],
        );
        const schema = `stage12_${randomUUID().replaceAll('-', '')}`;
        const runner = db.createQueryRunner();
        await runner.connect();
        try {
          await runner.query(`CREATE SCHEMA "${schema}"`);
          await runner.query(`SET search_path TO "${schema}"`);
          await new CreateUsers1789776000000().up(runner);
          await new CreateParkings1790380800000().up(runner);
          await new CreateParkingSpaces1790553600000().up(runner);
          const migration = new CreateReservations1790640000000();
          await migration.up(runner);
          await migration.down(runner);
          await migration.up(runner);
          const result = await runner.query(
            'SELECT table_name FROM information_schema.tables WHERE table_schema=$1 AND table_name=$2',
            [schema, 'reservations'],
          );
          assert.equal(result.length, 1);
        } finally {
          for (const table of [
            'reservations',
            'parking_spaces',
            'parkings',
            'users',
          ])
            await runner.query(`DROP TABLE IF EXISTS "${schema}"."${table}"`);
          await runner.query('SET search_path TO public');
          await runner.query(`DROP SCHEMA "${schema}"`);
          await runner.release();
        }
      },
    );
  } finally {
    await app.close();
  }
});
