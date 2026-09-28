const { after, before, test } = require('node:test');
const assert = require('node:assert/strict');
const { Module } = require('@nestjs/common');
const { NestFactory } = require('@nestjs/core');
const { DataSource } = require('typeorm');
const { HealthController } = require('../dist/health.controller');
const { configureApp } = require('../dist/setup');

let app;
let baseUrl;
let databaseUnavailable = false;
class TestModule {}
Module({
  controllers: [HealthController],
  providers: [
    {
      provide: DataSource,
      useValue: {
        query: async () => {
          if (databaseUnavailable)
            throw new Error('private connection details');
          return [{ health: 1 }];
        },
      },
    },
  ],
})(TestModule);

before(async () => {
  app = await NestFactory.create(TestModule, { logger: false });
  configureApp(app);
  await app.listen(0, '127.0.0.1');
  baseUrl = await app.getUrl();
});
after(async () => {
  await app?.close();
});

test('GET /health remains outside /api and returns JSON', async () => {
  const response = await fetch(`${baseUrl}/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: 'ok',
    service: 'easypark-backend',
  });
  assert.equal((await fetch(`${baseUrl}/api/health`)).status, 404);
});

test('database failure returns 503 without private details, then recovers', async () => {
  databaseUnavailable = true;
  try {
    const response = await fetch(`${baseUrl}/health`);
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), {
      status: 'error',
      service: 'easypark-backend',
      database: 'unavailable',
    });
  } finally {
    databaseUnavailable = false;
  }
  assert.equal((await fetch(`${baseUrl}/health`)).status, 200);
});

test('business endpoints are not exposed in stage 1', async () => {
  assert.equal((await fetch(`${baseUrl}/api/parkings`)).status, 404);
});
