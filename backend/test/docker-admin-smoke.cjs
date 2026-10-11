// Run after docker compose up -d --build --wait backend. Never print credentials.
const assert = require('node:assert/strict');
const { resolve } = require('node:path');
const { NestFactory } = require('@nestjs/core');
const { DataSource } = require('typeorm');
const { ConfigService } = require('@nestjs/config');
const { AppModule } = require('../dist/app.module');
const {
  AdminBootstrapService,
} = require('../dist/auth/admin-bootstrap.service');
const { PasswordService } = require('../dist/auth/password.service');

async function main() {
  process.loadEnvFile(resolve(__dirname, '../../.env'));
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
    abortOnError: false,
  });
  try {
    const config = app.get(ConfigService);
    const db = app.get(DataSource);
    const login = config.getOrThrow('ADMIN_LOGIN');
    const password = config.getOrThrow('ADMIN_PASSWORD');
    const base = `http://127.0.0.1:${process.env.BACKEND_PORT || 3000}`;
    assert.equal((await fetch(`${base}/health`)).status, 200);
    const authenticate = async (supplied) => {
      const response = await fetch(`${base}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ login, password: supplied }),
      });
      return { status: response.status, body: await response.json() };
    };
    assert.equal(
      (await authenticate('incorrect-a2-smoke-password')).status,
      401,
    );
    const session = await authenticate(password);
    assert.equal(session.status, 200);
    assert.equal(session.body.user.role, 'ADMIN');
    assert.equal('passwordHash' in session.body.user, false);
    const me = await fetch(`${base}/api/users/me`, {
      headers: { Authorization: `Bearer ${session.body.accessToken}` },
    });
    assert.equal(me.status, 200);
    const user = await me.json();
    assert.equal(user.role, 'ADMIN');
    assert.equal('passwordHash' in user, false);
    const rows = await db.query(
      'SELECT "passwordHash", role FROM users WHERE login = $1',
      [login],
    );
    assert.equal(rows.length, 1);
    assert.equal(rows[0].role, 'ADMIN');
    assert.notEqual(rows[0].passwordHash, password);
    assert.equal(
      await app.get(PasswordService).verify(password, rows[0].passwordHash),
      true,
    );
    await app.get(AdminBootstrapService).ensureAdmin();
    const after = await db.query(
      'SELECT "passwordHash" FROM users WHERE login = $1',
      [login],
    );
    assert.equal(after.length, 1);
    assert.equal(after[0].passwordHash, rows[0].passwordHash);
    console.log(
      'ADMIN Docker smoke passed: login, rejection, JWT, safe response, hashed storage, idempotent bootstrap.',
    );
  } finally {
    await app.close();
  }
}
main().catch(() => {
  console.error(
    'ADMIN Docker smoke failed; credentials and response bodies are withheld.',
  );
  process.exitCode = 1;
});
