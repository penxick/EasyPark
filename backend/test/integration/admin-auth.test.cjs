const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { Controller, Get, UseGuards, Module } = require('@nestjs/common');
const { ConfigService } = require('@nestjs/config');
const { DataSource } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { AuthModule } = require('../../dist/auth/auth.module');
const { configureApp } = require('../../dist/setup');
const { User } = require('../../dist/users/user.entity');
const { PasswordService } = require('../../dist/auth/password.service');
const {
  AdminBootstrapService,
  SYSTEM_ADMIN_EMAIL,
} = require('../../dist/auth/admin-bootstrap.service');
const { JwtAuthGuard } = require('../../dist/auth/jwt-auth.guard');
const { RoleGuard } = require('../../dist/auth/role.guard');
const {
  CreateUsers1789776000000,
} = require('../../dist/database/migrations/1789776000000-create-users');
const {
  AddUserLogin1791331200000,
} = require('../../dist/database/migrations/1791331200000-add-user-login');

// Real Nest HTTP guard chain; no test-only endpoint is shipped in AppModule.
class AdminProbeController {
  probe() {
    return { allowed: true };
  }
}
Controller('admin/a2-probe')(AdminProbeController);
UseGuards(JwtAuthGuard, RoleGuard)(AdminProbeController);
Get()(
  AdminProbeController.prototype,
  'probe',
  Object.getOwnPropertyDescriptor(AdminProbeController.prototype, 'probe'),
);
class TestModule {}
Module({
  imports: [AppModule, AuthModule],
  controllers: [AdminProbeController],
})(TestModule);

test(
  'ADMIN bootstrap and HTTP authorization',
  { timeout: 120000 },
  async (t) => {
    const app = await NestFactory.create(TestModule, {
      logger: false,
      abortOnError: false,
    });
    const db = app.get(DataSource);
    const schema = `a2_${randomUUID().replaceAll('-', '')}`;
    const login = `a2-${randomUUID()}`;
    const email = `${login}@example.com`;
    const password = 'A2-test-only-password!';
    let isolated;
    let adminId;
    let userId;
    try {
      await db.query(`CREATE SCHEMA "${schema}"`);
      isolated = new DataSource({
        ...db.options,
        schema,
        entities: [User],
        migrations: [],
        extra: { ...db.options.extra, options: `-c search_path=${schema}` },
      });
      await isolated.initialize();
      const runner = isolated.createQueryRunner();
      await runner.connect();
      try {
        await new CreateUsers1789776000000().up(runner);
        const migration = new AddUserLogin1791331200000();
        await migration.up(runner);
        await migration.down(runner);
        await migration.up(runner);
        await runner.query('ALTER TABLE users ADD COLUMN "tokenVersion" integer NOT NULL DEFAULT 0');
      } finally {
        await runner.release();
      }
      const passwords = app.get(PasswordService);
      const config = new ConfigService({
        ADMIN_LOGIN: login,
        ADMIN_PASSWORD: password,
      });
      const bootstrap = new AdminBootstrapService(isolated, config, passwords);
      await t.test(
        'concurrent bootstrap creates one ADMIN with a hash; restart preserves password',
        async () => {
          await Promise.all([
            bootstrap.ensureAdmin(),
            bootstrap.ensureAdmin(),
            bootstrap.ensureAdmin(),
          ]);
          const users = await isolated.getRepository(User).find();
          assert.equal(users.length, 1);
          assert.equal(users[0].role, 'ADMIN');
          assert.equal(users[0].login, login);
          assert.equal(users[0].passwordHash, undefined);
          const [{ passwordHash }] = await isolated.query(
            'SELECT "passwordHash" FROM users',
          );
          assert.notEqual(passwordHash, password);
          assert.equal(await passwords.verify(password, passwordHash), true);
          config.set('ADMIN_PASSWORD', 'Changed-test-only-password!');
          await bootstrap.ensureAdmin();
          assert.equal(
            (await isolated.query('SELECT "passwordHash" FROM users'))[0]
              .passwordHash,
            passwordHash,
          );
          const drift = await isolated.driver.createSchemaBuilder().log();
          assert.deepEqual(
            drift.upQueries.map((q) => q.query),
            [],
          );
        },
      );
      await t.test(
        'identity conflict never promotes USER or creates a replacement',
        async () => {
          await isolated
            .getRepository(User)
            .update({ login }, { role: 'USER' });
          await assert.rejects(bootstrap.ensureAdmin(), /identity conflict/);
          assert.equal(
            (await isolated.getRepository(User).findOneByOrFail({ login }))
              .role,
            'USER',
          );
          assert.equal(await isolated.getRepository(User).count(), 1);
        },
      );

      const admin = await db.getRepository(User).save({
        name: 'A2 test',
        email,
        login,
        role: 'ADMIN',
        passwordHash: await passwords.hash(password),
      });
      adminId = admin.id;
      configureApp(app);
      await app.listen(0, '127.0.0.1');
      const base = `${await app.getUrl()}/api`;
      const post = async (route, body) => {
        const response = await fetch(base + route, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
        return { status: response.status, body: await response.json() };
      };
      const probe = async (token) =>
        (
          await fetch(base + '/admin/a2-probe', {
            headers: token ? { Authorization: `Bearer ${token}` } : {},
          })
        ).status;
      let adminToken;
      let userToken;
      await t.test(
        'login supports normalized login and legacy email; invalid credentials fail safely',
        async () => {
          const result = await post('/auth/login', {
            login: ` ${login.toUpperCase()} `,
            password,
          });
          assert.equal(result.status, 200);
          assert.equal(result.body.user.role, 'ADMIN');
          assert.equal(JSON.stringify(result.body).includes('password'), false);
          adminToken = result.body.accessToken;
          assert.equal(
            (await post('/auth/login', { email, password })).status,
            200,
          );
          assert.equal(
            (await post('/auth/login', { login: email, password })).status,
            200,
          );
          const wrong = await post('/auth/login', { login, password: 'wrong' });
          const unknown = await post('/auth/login', {
            login: 'no-such-a2-admin',
            password,
          });
          assert.equal(wrong.status, 401);
          assert.deepEqual(wrong.body, unknown.body);
          for (const body of [
            { password },
            { login, email, password },
            { login: null, password },
            { login: '', password },
          ]) {
            assert.equal((await post('/auth/login', body)).status, 400);
          }
        },
      );
      await t.test(
        'registration remains USER-only and reserves system identity',
        async () => {
          const body = { name: 'Test USER', email: `user-${email}`, password };
          for (const extra of [
            { role: 'ADMIN' },
            { login: 'admin' },
            { login },
            { passwordHash: 'injected' },
          ]) {
            assert.equal(
              (await post('/auth/register', { ...body, ...extra })).status,
              400,
            );
          }
          assert.equal(
            (await post('/auth/register', { ...body, email: 'admin' })).status,
            400,
          );
          assert.equal(
            (
              await post('/auth/register', {
                ...body,
                email: SYSTEM_ADMIN_EMAIL.toUpperCase(),
              })
            ).status,
            409,
          );
          const result = await post('/auth/register', body);
          assert.equal(result.status, 201);
          userId = result.body.user.id;
          userToken = result.body.accessToken;
          assert.equal(result.body.user.role, 'USER');
          assert.equal(JSON.stringify(result.body).includes('password'), false);
        },
      );
      await t.test(
        'HTTP guards enforce 401/403/200 and immediately honor role revocation',
        async () => {
          assert.equal(await probe(), 401);
          assert.equal(await probe('invalid'), 401);
          assert.equal(await probe(userToken), 403);
          assert.equal(await probe(adminToken), 200);
          await db.getRepository(User).update(adminId, { role: 'USER' });
          assert.equal(await probe(adminToken), 403);
          await db.getRepository(User).delete(adminId);
          assert.equal(await probe(adminToken), 401);
        },
      );
    } finally {
      if (adminId) await db.getRepository(User).delete(adminId);
      if (userId) await db.getRepository(User).delete(userId);
      if (isolated?.isInitialized) {
        await isolated.query(`DROP TABLE IF EXISTS "${schema}"."users"`);
        await isolated.destroy();
      }
      await db.query(`DROP SCHEMA IF EXISTS "${schema}"`);
      await app.close();
    }
  },
);
