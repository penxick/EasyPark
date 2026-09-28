const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  PasswordService,
  DUMMY_PASSWORD_HASH,
} = require('../dist/auth/password.service');

test('password hashing uses random salts and verifies full Unicode passwords', async () => {
  const passwords = new PasswordService();
  const value = '  Длинный пароль 🔑  ';
  const first = await passwords.hash(value);
  const second = await passwords.hash(value);
  assert.notEqual(first, second);
  assert.ok(first.startsWith('scrypt$32768$8$3$'));
  assert.ok(!first.includes(value));
  assert.equal(await passwords.verify(value, first), true);
  assert.equal(await passwords.verify(value.trim(), first), false);
  assert.equal(await passwords.verify('incorrect-password', first), false);
});

test('malformed stored hashes and unknown-user dummy cannot authenticate', async () => {
  const passwords = new PasswordService();
  for (const value of [
    '',
    'plaintext',
    'scrypt$9999999999$8$1$invalid$invalid',
  ]) {
    assert.equal(await passwords.verify('password', value), false);
  }
  assert.equal(await passwords.verify('password', DUMMY_PASSWORD_HASH), false);
});
