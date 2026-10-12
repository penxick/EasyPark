const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { JwtService } = require('@nestjs/jwt');
const { DataSource } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const { User } = require('../../dist/users/user.entity');

test(
  '30-minute tariff is exact, editable and does not change history',
  { timeout: 60000 },
  async () => {
    const app = await NestFactory.create(AppModule, {
      logger: false,
      abortOnError: false,
    });
    const db = app.get(DataSource);
    let admin, parkingId;
    try {
      configureApp(app);
      await app.listen(0, '127.0.0.1');
      admin = await db.getRepository(User).save({
        name: 'Pricing test',
        email: `${randomUUID()}@example.com`,
        passwordHash: 'not-for-login',
        role: 'ADMIN',
      });
      const token = app.get(JwtService).sign({ sub: String(admin.id) });
      const request = async (method, path, body, status = 200) => {
        const r = await fetch(`${await app.getUrl()}/api${path}`, {
          method,
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`,
          },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        });
        assert.equal(r.status, status);
        return r.json();
      };
      const payload = {
        name: 'Pricing test',
        description: 'Test',
        address: 'Test',
        latitude: 0,
        longitude: 0,
        pricePerHour: 999,
        workingHours: '24/7',
        pricePer30Min: '50.01',
      };
      const parking = await request('POST', '/admin/parkings', payload, 201);
      parkingId = parking.id;
      assert.equal(parking.pricePer30Min, '50.01');
      for (const value of [
        '-1',
        '0.001',
        '1e3',
        null,
        '100000000',
        {},
        'NaN',
      ]) {
        await request(
          'PATCH',
          `/admin/parkings/${parkingId}`,
          { pricePer30Min: value },
          400,
        );
      }
      const space = await request(
        'POST',
        `/admin/parkings/${parkingId}/spaces`,
        { code: 'T01', x: 0, y: 0, polygon: null },
        201,
      );
      let first;
      for (const durationMinutes of [30, 60, 90, 120, 150, 180]) {
        const r = await request(
          'POST',
          '/reservations',
          { parkingSpaceId: space.id, durationMinutes },
          201,
        );
        assert.equal(r.totalPrice, (5001 * (durationMinutes / 30)) / 100);
        const row = await db.query(
          'SELECT "totalPrice"::text AS price FROM reservations WHERE id=$1',
          [r.id],
        );
        assert.equal(
          row[0].price,
          ((5001 * (durationMinutes / 30)) / 100).toFixed(2),
        );
        first ??= r;
        await request('PATCH', `/reservations/${r.id}/cancel`, {});
      }
      for (const durationMinutes of [0, 29, 31, 45, 181, 210, 1440])
        await request(
          'POST',
          '/reservations',
          { parkingSpaceId: space.id, durationMinutes },
          400,
        );
      await request('PATCH', `/admin/parkings/${parkingId}`, {
        pricePer30Min: '0.10',
      });
      const history = await request('GET', `/admin/reservations/${first.id}`);
      assert.equal(history.totalPrice, 50.01);
      const updated = await request(
        'POST',
        '/reservations',
        { parkingSpaceId: space.id, durationMinutes: 90 },
        201,
      );
      assert.equal(updated.totalPrice, 0.3);
      const visible = await request('GET', `/parkings/${parkingId}`);
      assert.equal(visible.pricePer30Min, '0.10');
    } finally {
      if (parkingId) {
        await db.query(
          'DELETE FROM reservations WHERE "parkingSpaceId" IN (SELECT id FROM parking_spaces WHERE "parkingId"=$1)',
          [parkingId],
        );
        await db.query('DELETE FROM parking_spaces WHERE "parkingId"=$1', [
          parkingId,
        ]);
        await db.query('DELETE FROM parkings WHERE id=$1', [parkingId]);
      }
      if (admin) await db.getRepository(User).delete(admin.id);
      await app.close();
    }
  },
);
