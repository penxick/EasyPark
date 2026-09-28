const { NestFactory } = require('@nestjs/core');
const { DataSource } = require('typeorm');
const { JwtService } = require('@nestjs/jwt');
const { AppModule } = require('../dist/app.module');
const {
  ReservationsService,
} = require('../dist/reservations/reservations.service');
const { reservationScenario } = require('./support/reservation-scenario.cjs');
const {
  ReservationExpiryWorker,
} = require('../dist/reservations/reservation-expiry.worker');

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
    abortOnError: false,
  });
  try {
    // Only the actual Docker server may run the background-expiry check here.
    await app.get(ReservationExpiryWorker).onModuleDestroy();
    await reservationScenario({
      waitForWorker: true,
      db: app.get(DataSource),
      base: 'http://127.0.0.1:3000/api',
      jwt: app.get(JwtService),
      service: app.get(ReservationsService),
      test: async (name, fn) => {
        await fn();
        console.log(`Passed: ${name}`);
      },
    });
    console.log('Docker reservation smoke passed; owned fixtures removed.');
  } finally {
    await app.close();
  }
}
void main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
