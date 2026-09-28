// Explicit smoke check: restarts only this project's backend container.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { resolve } = require('node:path');
const { setTimeout: delay } = require('node:timers/promises');
const { Client } = require('pg');

async function main() {
  const root = resolve(__dirname, '../..');
  process.loadEnvFile(resolve(root, '.env'));
  const base = `http://127.0.0.1:${process.env.BACKEND_PORT || 3000}`;
  const email = `smoke-stage4-${randomUUID()}@example.com`;
  const password = randomUUID();
  const db = new Client({
    host: '127.0.0.1',
    port: Number(process.env.POSTGRES_PORT || 55432),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
  });
  await db.connect();
  try {
    const registered = await fetch(`${base}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Smoke check', email, password }),
    });
    assert.equal(registered.status, 201);
    const { accessToken, user } = await registered.json();
    assert.equal(user.email, email);
    assert.equal(user.role, 'USER');
    assert.equal(user.passwordHash, undefined);
    execFileSync('docker', ['compose', 'restart', 'backend'], {
      cwd: root,
      stdio: 'pipe',
      timeout: 60000,
    });
    let healthy = false;
    for (let attempt = 0; attempt < 45; attempt++) {
      try {
        if (
          (await fetch(`${base}/health`, { signal: AbortSignal.timeout(2000) }))
            .ok
        ) {
          healthy = true;
          break;
        }
      } catch {
        /* Container may still be restarting. */
      }
      await delay(1000);
    }
    assert.ok(healthy, 'Backend did not recover after restart');
    const profile = await fetch(`${base}/api/users/me`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    assert.equal(profile.status, 200);
    assert.equal((await profile.json()).id, user.id);
    const login = await fetch(`${base}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    assert.equal(login.status, 200);
    assert.equal((await login.json()).user.id, user.id);
    console.log(
      'Docker auth smoke passed: registration, backend restart, existing JWT, persisted login.',
    );
  } finally {
    await db.query('DELETE FROM users WHERE email = $1', [email]);
    await db.end();
  }
}

void main().catch((error) => {
  console.error('Docker auth smoke failed:', error.message);
  process.exitCode = 1;
});
