import { seedParkingSpaces } from './parking-space-seed';
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { DataSource } from 'typeorm';
import { AppModule } from '../app.module';
import { seedParkings } from './parking-seed';

async function seed() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    abortOnError: false,
  });
  try {
    console.log(
      `Demo parkings inserted: ${await seedParkings(app.get(DataSource))}`,
    );
    console.log(
      `Demo parking spaces inserted: ${await seedParkingSpaces(app.get(DataSource))}`,
    );
  } finally {
    await app.close();
  }
}
void seed().catch(() => {
  console.error('Parking seed failed. Run migrations first.');
  process.exitCode = 1;
});
