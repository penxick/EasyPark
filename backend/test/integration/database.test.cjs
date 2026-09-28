const { test } = require('node:test');
const assert = require('node:assert/strict');
const { NestFactory } = require('@nestjs/core');
const { DataSource } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');

test('real AppModule connects to PostgreSQL and serves health', async () => {
  const app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  try {
    configureApp(app);
    const db = app.get(DataSource);
    assert.equal(db.isInitialized, true);
    assert.equal(db.options.synchronize, false);
    assert.equal(db.options.migrationsRun, false);
    assert.equal((await db.query('SELECT 1 AS health'))[0].health, 1);
    await app.listen(0, '127.0.0.1');
    const response = await fetch(`${await app.getUrl()}/health`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      status: 'ok',
      service: 'easypark-backend',
    });
  } finally {
    await app.close();
  }
});
