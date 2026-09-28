const { test } = require('node:test');
const assert = require('node:assert/strict');
const { validateEnvironment } = require('../dist/config/environment');
const valid = {
  POSTGRES_DB: 'test',
  POSTGRES_USER: 'tester',
  POSTGRES_PASSWORD: 'test-secret',
  JWT_SECRET: 'a'.repeat(64),
};

test('environment defaults, numeric ports and explicit PORT precedence', () => {
  const config = validateEnvironment({ ...valid, BACKEND_PORT: '3100' });
  assert.equal(config.PORT, 3100);
  assert.equal(config.POSTGRES_PORT, 55432);
  assert.equal(config.DB_HOST, '127.0.0.1');
  assert.equal(
    validateEnvironment({ ...valid, PORT: '3200', BACKEND_PORT: '3100' }).PORT,
    3200,
  );
});

test('missing DB settings fail without exposing secrets', () => {
  for (const key of Object.keys(valid)) {
    assert.throws(
      () => validateEnvironment({ ...valid, [key]: '  ' }),
      new RegExp(key),
    );
  }
});

test('invalid ports and empty hosts fail early', () => {
  for (const key of ['PORT', 'POSTGRES_PORT']) {
    for (const value of ['', '0', '-1', '65536', '3.5', 'abc', '1e3']) {
      assert.throws(
        () => validateEnvironment({ ...valid, [key]: value }),
        new RegExp(key),
      );
    }
  }
  assert.throws(
    () => validateEnvironment({ ...valid, DB_HOST: '' }),
    /DB_HOST/,
  );
});

test('JWT rejects missing, short or placeholder secrets without exposing them', () => {
  for (const secret of [
    undefined,
    '',
    'short',
    'replace_with_random_secret_at_least_32_bytes',
  ]) {
    assert.throws(
      () => validateEnvironment({ ...valid, JWT_SECRET: secret }),
      /JWT_SECRET/,
    );
  }
  assert.equal(validateEnvironment(valid).JWT_TTL_SECONDS, 604800);
  assert.equal(
    validateEnvironment({ ...valid, JWT_TTL_SECONDS: '60' }).JWT_TTL_SECONDS,
    60,
  );
  for (const ttl of ['0', '59', '2592001', '1h', '10.5', '']) {
    assert.throws(
      () => validateEnvironment({ ...valid, JWT_TTL_SECONDS: ttl }),
      /JWT_TTL_SECONDS/,
    );
  }
});
