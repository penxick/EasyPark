import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { DataSource } from 'typeorm';
import { AppModule } from '../app.module';

async function migrate() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    abortOnError: false,
  });
  try {
    const migrations = await app
      .get(DataSource)
      .runMigrations({ transaction: 'all' });
    console.log(`Applied migrations: ${migrations.length}`);
  } finally {
    await app.close();
  }
}

void migrate().catch(() => {
  console.error('Database migration failed. Backend was not started.');
  process.exitCode = 1;
});
