const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { JwtService } = require('@nestjs/jwt');
const { ConfigService } = require('@nestjs/config');
const { DataSource } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const { User } = require('../../dist/users/user.entity');
const { PasswordService } = require('../../dist/auth/password.service');
const {
  CreateUsers1789776000000,
} = require('../../dist/database/migrations/1789776000000-create-users');

test('Auth API with real PostgreSQL', { timeout: 120000 }, async (t) => {
  const app = await NestFactory.create(AppModule, {
    logger: false,
    abortOnError: false,
  });
  const db = app.get(DataSource);
  const emails = [];
  const email = `stage4-${randomUUID()}@example.com`;
  const password = '  Надёжный пароль 🔑  ';
  let session;
  try {
    configureApp(app);
    await app.listen(0, '127.0.0.1');
    const base = `${await app.getUrl()}/api`;
    const post = async (route, body) => {
      const response = await fetch(`${base}${route}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      return {
        status: response.status,
        headers: response.headers,
        body: await response.json(),
      };
    };
    const me = async (token, headers = {}) => {
      const response = await fetch(`${base}/users/me`, {
        headers: {
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...headers,
        },
      });
      return { status: response.status, body: await response.json() };
    };
    const assertPublic = (user) => {
      assert.deepEqual(
        Object.keys(user).sort(),
        ['id', 'name', 'email', 'role', 'createdAt', 'updatedAt'].sort(),
      );
      assert.equal(user.email, email);
      assert.ok(Number.isInteger(user.id));
      assert.ok(Number.isFinite(Date.parse(user.createdAt)));
    };

    await t.test(
      'migration up/down works in a separate temporary schema',
      async () => {
        const drift = await db.driver.createSchemaBuilder().log();
        assert.deepEqual(
          drift.upQueries.map((query) => query.query),
          [],
        );
        const schema = `stage4_${randomUUID().replaceAll('-', '')}`;
        const runner = db.createQueryRunner();
        await runner.connect();
        try {
          await runner.query(`CREATE SCHEMA "${schema}"`);
          await runner.query(`SET search_path TO "${schema}"`);
          const migration = new CreateUsers1789776000000();
          await migration.up(runner);
          const tables = await runner.query(
            'SELECT table_name FROM information_schema.tables WHERE table_schema = $1',
            [schema],
          );
          assert.deepEqual(
            tables.map((row) => row.table_name),
            ['users'],
          );
          await migration.down(runner);
          assert.equal(
            (
              await runner.query(
                'SELECT table_name FROM information_schema.tables WHERE table_schema = $1',
                [schema],
              )
            ).length,
            0,
          );
        } finally {
          await runner.query('SET search_path TO public');
          // No CASCADE: drop only this empty, test-created schema.
          await runner.query(`DROP SCHEMA "${schema}"`);
          await runner.release();
        }
      },
    );

    await t.test(
      'register normalizes identity, persists only a hash and returns a JWT',
      async () => {
        emails.push(email);
        const response = await post('/auth/register', {
          name: '  Роман  ',
          email: `  ${email.toUpperCase()}  `,
          password,
        });
        assert.equal(response.status, 201);
        assert.equal(response.headers.get('cache-control'), 'no-store');
        session = response.body;
        assertPublic(session.user);
        assert.equal(session.user.name, 'Роман');
        assert.equal(session.user.role, 'USER');
        assert.equal(typeof session.accessToken, 'string');
        assert.equal((await me(session.accessToken)).status, 200);
        const row = await db.getRepository(User).findOneByOrFail({ email });
        assert.equal(row.passwordHash, undefined);
        const [{ passwordHash }] = await db.query(
          'SELECT "passwordHash" FROM users WHERE email = $1',
          [email],
        );
        assert.notEqual(passwordHash, password);
        assert.equal(
          await app.get(PasswordService).verify(password, passwordHash),
          true,
        );
        assert.ok(!JSON.stringify(session).includes(passwordHash));
      },
    );

    await t.test(
      'duplicate and simultaneous registrations create exactly one user',
      async () => {
        assert.equal(
          (
            await post('/auth/register', {
              name: 'Другой',
              email: email.toUpperCase(),
              password,
            })
          ).status,
          409,
        );
        const concurrentEmail = `stage4-${randomUUID()}@example.com`;
        emails.push(concurrentEmail);
        const results = await Promise.all(
          [1, 2].map(() =>
            post('/auth/register', {
              name: 'Concurrent',
              email: concurrentEmail,
              password,
            }),
          ),
        );
        assert.deepEqual(
          results.map((result) => result.status).sort(),
          [201, 409],
        );
        assert.equal(
          await db.getRepository(User).countBy({ email: concurrentEmail }),
          1,
        );
      },
    );

    await t.test(
      'invalid input and injected role are rejected before persistence',
      async () => {
        const valid = {
          name: 'Роман',
          email: `stage4-${randomUUID()}@example.com`,
          password,
        };
        for (const override of [
          { name: '  ' },
          { name: 'x'.repeat(101) },
          { email: 'invalid' },
          { email: 42 },
          { password: 'short' },
          { password: ' '.repeat(8) },
          { password: 'x'.repeat(129) },
          { password: null },
          { role: 'ADMIN' },
          { passwordHash: 'injected' },
        ]) {
          const response = await post('/auth/register', {
            ...valid,
            ...override,
          });
          assert.equal(response.status, 400);
          assert.ok(!JSON.stringify(response.body).includes(password));
        }
        assert.equal(
          await db.getRepository(User).countBy({ email: valid.email }),
          0,
        );
        assert.equal(
          (await post('/auth/login', { email, password, role: 'ADMIN' }))
            .status,
          400,
        );
      },
    );

    await t.test(
      'login works and unknown email has the same error as a wrong password',
      async () => {
        const correct = await post('/auth/login', {
          email: email.toUpperCase(),
          password,
        });
        assert.equal(correct.status, 200);
        assertPublic(correct.body.user);
        assert.equal((await me(correct.body.accessToken)).status, 200);
        const wrong = await post('/auth/login', {
          email,
          password: 'wrong-password',
        });
        const unknown = await post('/auth/login', {
          email: `missing-${randomUUID()}@example.com`,
          password,
        });
        assert.equal(wrong.status, 401);
        assert.equal(unknown.status, 401);
        assert.deepEqual(wrong.body, unknown.body);
        assert.equal(
          (await post('/auth/login', { email, password: password.trim() }))
            .status,
          401,
        );
      },
    );

    await t.test(
      'me rejects missing, malformed, expired and forged JWTs',
      async () => {
        const jwt = app.get(JwtService);
        const sub = String(session.user.id);
        const signed = (payload, options) => jwt.signAsync(payload, options);
        const tokens = [
          'malformed',
          await signed({ sub }, { expiresIn: -1 }),
          await signed(
            { sub },
            { secret: 'different-secret-not-valid-for-this-server' },
          ),
          await signed({ sub }, { issuer: 'another-app' }),
          await signed({ sub }, { audience: 'another-client' }),
          await signed({ sub }, { algorithm: 'HS384' }),
          await new JwtService({
            secret: app.get(ConfigService).getOrThrow('JWT_SECRET'),
          }).signAsync(
            { sub },
            {
              issuer: 'easypark-backend',
              audience: 'easypark-mobile',
              algorithm: 'HS256',
            },
          ),
          await signed({ sub: 'not-a-number' }),
          await signed({ sub: '2147483647' }),
        ];
        assert.equal((await me()).status, 401);
        assert.equal(
          (await me(undefined, { Authorization: 'Basic credentials' })).status,
          401,
        );
        for (const token of tokens) assert.equal((await me(token)).status, 401);
        assert.equal((await me(session.accessToken)).status, 200);
      },
    );

    await t.test(
      'me reads current DB role and deleted users cannot reuse JWTs',
      async () => {
        await db.getRepository(User).update({ email }, { role: 'ADMIN' });
        const response = await me(session.accessToken);
        assert.equal(response.status, 200);
        assertPublic(response.body);
        assert.equal(response.body.role, 'ADMIN');
        await db.getRepository(User).delete({ email });
        assert.equal((await me(session.accessToken)).status, 401);
      },
    );

    await t.test(
      'authentication endpoints limit requests and return retry delay',
      async () => {
        let response;
        for (let index = 0; index < 21; index++) {
          response = await post('/auth/login', {});
          if (response.status === 429) break;
        }
        assert.equal(response.status, 429);
        assert.ok(Number(response.headers.get('retry-after')) > 0);
        assert.equal((await fetch(`${await app.getUrl()}/health`)).status, 200);
      },
    );
  } finally {
    // Delete only exact random addresses allocated by this test, never truncate.
    for (const email of emails) await db.getRepository(User).delete({ email });
    await app.close();
  }
});
