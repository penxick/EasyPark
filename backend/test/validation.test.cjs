require('reflect-metadata');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { IsEmail } = require('class-validator');
const { createValidationPipe } = require('../dist/setup');
class ExampleDto {}
IsEmail()(ExampleDto.prototype, 'email');
const metadata = { type: 'body', metatype: ExampleDto };

test('validation converts valid payload to DTO instance', async () => {
  const result = await createValidationPipe().transform(
    { email: 'test@example.com' },
    metadata,
  );
  assert.ok(result instanceof ExampleDto);
});

test('validation rejects missing, invalid and extra fields with 400', async () => {
  for (const body of [
    {},
    { email: 'invalid' },
    { email: 'test@example.com', admin: true },
  ]) {
    await assert.rejects(
      () => createValidationPipe().transform(body, metadata),
      (error) => error.getStatus() === 400,
    );
  }
});
