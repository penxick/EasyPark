// Temporary Android E2E identities. Never prints credentials; cleanup is scoped to saved IDs.
const {
  mkdirSync,
  writeFileSync,
  readFileSync,
  unlinkSync,
  existsSync,
} = require('node:fs');
const { resolve } = require('node:path');
const { randomUUID, randomBytes } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { DataSource } = require('typeorm');
const { AppModule } = require('../dist/app.module');
const { User } = require('../dist/users/user.entity');
const { PasswordService } = require('../dist/auth/password.service');
const path = resolve(__dirname, '../../.artifacts/a13-fixture.json');
async function main() {
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: false,
    abortOnError: false,
  });
  try {
    const db = app.get(DataSource);
    if (process.argv[2] === 'prepare') {
      if (existsSync(path))
        throw new Error('Clean up previous A13 fixture first');
      const tag = `a13-${randomUUID()}`;
      const password = randomBytes(24).toString('hex');
      const user = await db
        .getRepository(User)
        .save({
          name: tag,
          email: `${tag}@example.com`,
          login: tag,
          role: 'ADMIN',
          passwordHash: await app.get(PasswordService).hash(password),
        });
      mkdirSync(resolve(path, '..'), { recursive: true });
      writeFileSync(
        path,
        JSON.stringify({
          TEST_LOGIN: tag,
          TEST_PASSWORD: password,
          TEST_EMAIL: `${tag}-user@example.com`,
          ADMIN_ID: user.id,
        }),
      );
      console.log('Temporary Android fixture prepared');
    } else if (process.argv[2] === 'cleanup') {
      const fixture = JSON.parse(readFileSync(path, 'utf8'));
      if (!/^a13-[a-f0-9-]{36}$/.test(fixture.TEST_LOGIN))
        throw new Error('Invalid fixture scope');
      await db.transaction(async (tx) => {
        const parks = await tx.query('SELECT id FROM parkings WHERE name=$1', [
          fixture.TEST_LOGIN,
        ]);
        const ids = parks.map((p) => p.id);
        await tx.query(
          'DELETE FROM reservations WHERE "parkingSpaceId" IN (SELECT id FROM parking_spaces WHERE "parkingId" = ANY($1::int[])) OR "userId" IN (SELECT id FROM users WHERE email=$2)',
          [ids, fixture.TEST_EMAIL],
        );
        await tx.query(
          'DELETE FROM parking_spaces WHERE "parkingId" = ANY($1::int[])',
          [ids],
        );
        await tx.query('DELETE FROM parkings WHERE id = ANY($1::int[])', [ids]);
        await tx.query(
          'DELETE FROM users WHERE (id=$1 AND login=$2) OR email=$3',
          [fixture.ADMIN_ID, fixture.TEST_LOGIN, fixture.TEST_EMAIL],
        );
      });
      unlinkSync(path);
      console.log(
        'Temporary A13 accounts, parking, spaces and reservations removed',
      );
    } else throw new Error('Use prepare or cleanup');
  } finally {
    await app.close();
  }
}
main().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
