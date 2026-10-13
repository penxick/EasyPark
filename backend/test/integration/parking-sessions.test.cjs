const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID, createHmac } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { ConfigService } = require('@nestjs/config');
const { JwtService } = require('@nestjs/jwt');
const { DataSource } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const { User } = require('../../dist/users/user.entity');
const { hourlyCost } = require('../../dist/reservations/money');

test('hourly arithmetic rounds only the monetary result', () => {
  for (const [minutes, expected] of [
    [30, '40.00'],
    [60, '80.00'],
    [90, '120.00'],
    [135, '180.00'],
  ])
    assert.equal(hourlyCost('80.00', minutes * 60), expected);
  assert.equal(hourlyCost('1.00', 18), '0.01');
  assert.equal(hourlyCost('80.01', 1), '0.02');
});
test(
  'session lifecycle, ownership, demo roles and one-use password reset',
  { timeout: 60000 },
  async () => {
    const app = await NestFactory.create(AppModule, {
      logger: false,
      abortOnError: false,
    });
    configureApp(app);
    await app.listen(0, '127.0.0.1');
    const db = app.get(DataSource),
      config = app.get(ConfigService),
      jwt = app.get(JwtService);
    config.set('DEMO_PARKING_EVENTS_ENABLED', 'true');
    let admin, user, other, parking;
    const request = async (who, method, path, body, status = 200) => {
      const r = await fetch(`${await app.getUrl()}/api${path}`, {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(who
            ? { Authorization: `Bearer ${jwt.sign({ sub: String(who.id) })}` }
            : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      const data = await r.json();
      assert.equal(r.status, status, JSON.stringify(data));
      return data;
    };
    try {
      const make = (role) =>
        db.getRepository(User).save({
          name: 'Session test',
          email: `${randomUUID()}@example.com`,
          passwordHash: 'not-for-login',
          role,
        });
      admin = await make('ADMIN');
      user = await make('USER');
      other = await make('USER');
      parking = await request(
        admin,
        'POST',
        '/admin/parkings',
        {
          name: 'Session test',
          description: 'test',
          address: 'test',
          latitude: 0,
          longitude: 0,
          pricePerHour: 80,
          workingHours: '24/7',
        },
        201,
      );
      const space = await request(
        admin,
        'POST',
        `/admin/parkings/${parking.id}/spaces`,
        { code: 'B-5', x: 0, y: 0, polygon: null },
        201,
      );
      for (const mode of ['PLANNED', 'METERED']) {
        const payload = {
          parkingSpaceId: space.id,
          mode,
          paymentMethod: mode === 'PLANNED' ? 'SBP' : 'CARD',
          ...(mode === 'PLANNED' ? { plannedMinutes: 135 } : {}),
        };
        const attempts = await Promise.all(
          [0, 1].map(async () => {
            const r = await fetch(
              `${await app.getUrl()}/api/reservations/sessions`,
              {
                method: 'POST',
                headers: {
                  'Content-Type': 'application/json',
                  Authorization: `Bearer ${jwt.sign({ sub: String(user.id) })}`,
                },
                body: JSON.stringify(payload),
              },
            );
            return { status: r.status, body: await r.json() };
          }),
        );
        assert.deepEqual(attempts.map((a) => a.status).sort(), [201, 409]);
        const session = attempts.find((a) => a.status === 201).body;
        assert.equal(session.sessionState, 'WAITING_ARRIVAL');
        assert.equal(session.actualStartTime, null);
        assert.equal(
          session.preliminaryPrice,
          mode === 'PLANNED' ? '180.00' : null,
        );
        await request(
          other,
          'PATCH',
          `/reservations/${session.id}/finish`,
          undefined,
          404,
        );
        await request(
          user,
          'POST',
          `/reservations/${session.id}/demo-event`,
          { event: 'ARRIVAL' },
          403,
        );
        await request(
          null,
          'POST',
          `/reservations/${session.id}/demo-event`,
          { event: 'ARRIVAL' },
          401,
        );
        const arrival = await request(
          admin,
          'POST',
          `/reservations/${session.id}/demo-event`,
          { event: 'ARRIVAL' },
          201,
        );
        const repeat = await request(
          admin,
          'POST',
          `/reservations/${session.id}/demo-event`,
          { event: 'ARRIVAL' },
          201,
        );
        assert.equal(arrival.actualStartTime, repeat.actualStartTime);
        await db.query(
          'UPDATE reservations SET "actualStartTime"=CURRENT_TIMESTAMP-interval \'135 minutes\', "endTime"="startTime"+interval \'1 second\' WHERE id=$1',
          [session.id],
        );
        const mine = await request(user, 'GET', '/reservations/me');
        assert.equal(
          mine.find((r) => r.id === session.id).sessionState,
          'PARKED',
        );
        await request(
          user,
          'PATCH',
          `/reservations/${session.id}/cancel`,
          undefined,
          409,
        );
        const waiting = await request(
          user,
          'PATCH',
          `/reservations/${session.id}/finish`,
        );
        assert.equal(waiting.sessionState, 'WAITING_DEPARTURE');
        const [occupied] = await db.query(
          'SELECT "physicalOccupied", status FROM parking_spaces WHERE id=$1',
          [space.id],
        );
        assert.equal(occupied.physicalOccupied, true);
        assert.equal(occupied.status, 'RESERVED');
        const done = await request(
          admin,
          'POST',
          `/reservations/${session.id}/demo-event`,
          { event: 'DEPARTURE' },
          201,
        );
        assert.equal(done.status, 'COMPLETED');
        assert.equal(done.finalPrice, '180.00');
        assert.equal(done.paymentStatus, 'DEMO_CONFIRMED');
        const duplicate = await request(
          admin,
          'POST',
          `/reservations/${session.id}/demo-event`,
          { event: 'DEPARTURE' },
          201,
        );
        assert.equal(duplicate.actualEndTime, done.actualEndTime);
        await request(admin, 'PATCH', `/admin/parkings/${parking.id}`, {
          pricePerHour: 100,
        });
        assert.equal(
          (await request(user, 'GET', '/reservations/me')).find(
            (r) => r.id === session.id,
          ).finalPrice,
          '180.00',
        );
        await request(admin, 'PATCH', `/admin/parkings/${parking.id}`, {
          pricePerHour: 80,
        });
      }
      config.set('SMTP_HOST', '');
      config.set('SMTP_FROM', '');
      await request(
        null,
        'POST',
        '/auth/password-reset/request',
        { email: user.email },
        503,
      );
      await request(
        null,
        'POST',
        '/auth/password-reset/request',
        { email: 'absent@example.com' },
        503,
      );
      const digest = (value) =>
        createHmac('sha256', config.get('JWT_SECRET'))
          .update(value)
          .digest('hex');
      const key = digest(`email:${user.email}`),
        code = '123456';
      await db.query(
        'INSERT INTO password_resets (key,"userId","codeHash","expiresAt",attempts,"requestedAt") VALUES ($1,$2,$3,CURRENT_TIMESTAMP+interval \'10 minutes\',0,CURRENT_TIMESTAMP)',
        [key, user.id, digest(`${user.email}:${code}`)],
      );
      await request(
        null,
        'POST',
        '/auth/password-reset/confirm',
        { email: user.email, code: '000000', password: 'new-test-password' },
        400,
      );
      await request(null, 'POST', '/auth/password-reset/confirm', {
        email: user.email,
        code,
        password: 'new-test-password',
      });
      await request(
        null,
        'POST',
        '/auth/password-reset/confirm',
        { email: user.email, code, password: 'another-password' },
        400,
      );
      await request(user, 'GET', '/users/me', undefined, 401);
      const login = await request(null, 'POST', '/auth/login', {
        email: user.email,
        password: 'new-test-password',
      });
      assert.ok(login.accessToken);
      assert.equal(login.user.passwordHash, undefined);
    } finally {
      if (parking) {
        await db.query(
          'DELETE FROM reservations WHERE "parkingSpaceId" IN (SELECT id FROM parking_spaces WHERE "parkingId"=$1)',
          [parking.id],
        );
        await db.query('DELETE FROM parking_spaces WHERE "parkingId"=$1', [
          parking.id,
        ]);
        await db.query('DELETE FROM parkings WHERE id=$1', [parking.id]);
      }
      for (const u of [admin, user, other])
        if (u) await db.query('DELETE FROM users WHERE id=$1', [u.id]);
      await app.close();
    }
  },
);
