const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { NestFactory } = require('@nestjs/core');
const { JwtService } = require('@nestjs/jwt');
const { DataSource, In } = require('typeorm');
const { AppModule } = require('../../dist/app.module');
const { configureApp } = require('../../dist/setup');
const { User } = require('../../dist/users/user.entity');
const { Parking } = require('../../dist/parking/parking.entity');
const {
  ParkingSpace,
} = require('../../dist/parking-spaces/parking-space.entity');
const { Reservation } = require('../../dist/reservations/reservation.entity');

test(
  'ADMIN Parking CRUD and USER consistency',
  { timeout: 90000 },
  async (t) => {
    const app = await NestFactory.create(AppModule, {
      logger: false,
      abortOnError: false,
    });
    const db = app.get(DataSource);
    const parkingIds = [],
      userIds = [],
      spaceIds = [];
    try {
      configureApp(app);
      await app.listen(0, '127.0.0.1');
      const base = `${await app.getUrl()}/api`;
      const identity = async (role) => {
        const user = await db.getRepository(User).save({
          name: 'A3 test',
          email: `${randomUUID()}@example.com`,
          passwordHash: 'not-a-login-hash',
          role,
        });
        userIds.push(user.id);
        return app.get(JwtService).sign({ sub: String(user.id) });
      };
      const admin = await identity('ADMIN'),
        user = await identity('USER');
      const request = async (method, path, body, token = admin) => {
        const response = await fetch(base + path, {
          method,
          headers: {
            'Content-Type': 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        });
        return {
          status: response.status,
          body: response.status === 204 ? null : await response.json(),
        };
      };
      const payload = {
        name: '  Тестовая парковка  ',
        description: 'Описание',
        address: 'Адрес',
        latitude: 56.01,
        longitude: 92.85,
        pricePerHour: 123.45,
        workingHours: 'Круглосуточно',
      };
      const create = async () => {
        const result = await request('POST', '/admin/parkings', payload);
        assert.equal(result.status, 201);
        parkingIds.push(result.body.id);
        return result.body;
      };
      const space = async (parkingId) => {
        const row = await db.getRepository(ParkingSpace).save({
          parkingId,
          code: `A${spaceIds.length}`,
          x: 0,
          y: 0,
          polygon: [
            [0, 0],
            [1, 0],
            [1, 1],
          ],
        });
        spaceIds.push(row.id);
        return row;
      };
      const parking = await create();
      await t.test(
        'all mutations require JWT and ADMIN; USER can read created parking',
        async () => {
          for (const [method, path, body] of [
            ['POST', '/admin/parkings', payload],
            ['PATCH', `/admin/parkings/${parking.id}`, { name: 'Denied' }],
            ['DELETE', `/admin/parkings/${parking.id}`, undefined],
          ]) {
            assert.equal((await request(method, path, body, null)).status, 401);
            assert.equal((await request(method, path, body, user)).status, 403);
          }
          assert.equal(parking.name, payload.name.trim());
          assert.equal(parking.totalSpaces, 0);
          assert.equal(parking.freeSpaces, 0);
          const detail = await request(
            'GET',
            `/parkings/${parking.id}`,
            undefined,
            user,
          );
          assert.equal(detail.status, 200);
          assert.deepEqual(detail.body, parking);
          const list = await request('GET', '/parkings', undefined, user);
          assert.deepEqual(
            list.body.find((p) => p.id === parking.id),
            parking,
          );
        },
      );
      await t.test(
        'strict create and patch validation rejects empty, null, range, type and injected fields',
        async () => {
          for (const field of Object.keys(payload)) {
            const missing = { ...payload };
            delete missing[field];
            assert.equal(
              (await request('POST', '/admin/parkings', missing)).status,
              400,
              field,
            );
            assert.equal(
              (
                await request('PATCH', `/admin/parkings/${parking.id}`, {
                  [field]: null,
                })
              ).status,
              400,
              field,
            );
          }
          for (const invalid of [
            { name: '   ' },
            { name: 'a'.repeat(201) },
            { address: '' },
            { address: 'a'.repeat(501) },
            { description: '' },
            { description: 'a'.repeat(10001) },
            { workingHours: ' ' },
            { workingHours: 'a'.repeat(201) },
            { latitude: 90.1 },
            { latitude: -90.1 },
            { longitude: 180.1 },
            { longitude: -180.1 },
            { latitude: '56' },
            { longitude: true },
            { pricePerHour: -1 },
            { pricePerHour: 100000000 },
            { pricePerHour: 1.001 },
            { pricePerHour: '10' },
            { id: 100 },
            { totalSpaces: 20 },
            { role: 'ADMIN' },
          ]) {
            assert.equal(
              (
                await request('POST', '/admin/parkings', {
                  ...payload,
                  ...invalid,
                })
              ).status,
              400,
            );
            assert.equal(
              (await request('PATCH', `/admin/parkings/${parking.id}`, invalid))
                .status,
              400,
            );
          }
          assert.equal(
            (await request('PATCH', `/admin/parkings/${parking.id}`, {}))
              .status,
            400,
          );
          for (const id of ['0', '-1', 'abc', '1.5', '2147483648']) {
            assert.equal(
              (await request('PATCH', `/admin/parkings/${id}`, { name: 'New' }))
                .status,
              400,
            );
            assert.equal(
              (await request('DELETE', `/admin/parkings/${id}`)).status,
              400,
            );
          }
          assert.equal(
            (
              await request('PATCH', '/admin/parkings/2147483647', {
                name: 'New',
              })
            ).status,
            404,
          );
          assert.equal(
            (await request('DELETE', '/admin/parkings/2147483647')).status,
            404,
          );
        },
      );
      await t.test(
        'partial edits, coordinates and zero price are visible through USER endpoints',
        async () => {
          const changes = {
            name: ' Изменено ',
            description: 'Новое описание',
            address: 'Новый адрес',
            latitude: -90,
            longitude: 180,
            pricePerHour: 0,
            workingHours: '09:00–18:00',
          };
          const result = await request(
            'PATCH',
            `/admin/parkings/${parking.id}`,
            changes,
          );
          assert.equal(result.status, 200);
          assert.equal(result.body.name, 'Изменено');
          assert.equal(result.body.latitude, -90);
          assert.equal(result.body.longitude, 180);
          assert.equal(result.body.pricePerHour, 0);
          const both = await Promise.all([
            request('PATCH', `/admin/parkings/${parking.id}`, {
              name: 'Concurrent name',
            }),
            request('PATCH', `/admin/parkings/${parking.id}`, {
              address: 'Concurrent address',
            }),
          ]);
          assert.ok(both.every((r) => r.status === 200));
          const detail = await request(
            'GET',
            `/parkings/${parking.id}`,
            undefined,
            user,
          );
          assert.equal(detail.body.name, 'Concurrent name');
          assert.equal(detail.body.address, 'Concurrent address');
          assert.equal(detail.body.description, changes.description);
          assert.equal(detail.body.workingHours, changes.workingHours);
        },
      );
      await t.test(
        'deletion removes empty parking and its unbooked spaces atomically',
        async () => {
          const child = await space(parking.id);
          const before = await request(
            'GET',
            `/parkings/${parking.id}`,
            undefined,
            user,
          );
          assert.equal(before.body.totalSpaces, 1);
          assert.equal(
            (await request('DELETE', `/admin/parkings/${parking.id}`)).status,
            204,
          );
          assert.equal(
            await db.getRepository(ParkingSpace).existsBy({ id: child.id }),
            false,
          );
          assert.equal(
            (await request('GET', `/parkings/${parking.id}`, undefined, user))
              .status,
            404,
          );
          assert.equal(
            (await request('DELETE', `/admin/parkings/${parking.id}`)).status,
            404,
          );
          const empty = await create();
          assert.equal(
            (await request('DELETE', `/admin/parkings/${empty.id}`)).status,
            204,
          );
        },
      );
      await t.test(
        'every reservation status prevents deletion and rollback preserves all spaces',
        async () => {
          const p = await create();
          const booked = await space(p.id),
            unbooked = await space(p.id);
          const booking = await db.getRepository(Reservation).save({
            userId: userIds[1],
            parkingSpaceId: booked.id,
            startTime: new Date(),
            endTime: new Date(Date.now() + 3600000),
            status: 'ACTIVE',
            totalPrice: 100,
          });
          for (const status of [
            'ACTIVE',
            'PENDING',
            'COMPLETED',
            'CANCELLED',
            'EXPIRED',
          ]) {
            await db.getRepository(Reservation).update(booking.id, { status });
            const result = await request('DELETE', `/admin/parkings/${p.id}`);
            assert.equal(result.status, 409);
            assert.equal(result.body.code, 'PARKING_HAS_RESERVATIONS');
            assert.equal(
              await db
                .getRepository(ParkingSpace)
                .existsBy({ id: unbooked.id }),
              true,
            );
            assert.equal(
              await db.getRepository(Parking).existsBy({ id: p.id }),
              true,
            );
            assert.equal(
              (
                await db
                  .getRepository(Reservation)
                  .findOneByOrFail({ id: booking.id })
              ).status,
              status,
            );
          }
          assert.equal(
            (
              await request('PATCH', `/admin/parkings/${p.id}`, {
                pricePerHour: 500,
              })
            ).status,
            200,
          );
          assert.equal(
            (
              await db
                .getRepository(Reservation)
                .findOneByOrFail({ id: booking.id })
            ).totalPrice,
            100,
          );
        },
      );
      await t.test(
        'concurrent booking and deletion never lose history or violate foreign keys',
        async () => {
          for (let iteration = 0; iteration < 4; iteration++) {
            const p = await create(),
              s = await space(p.id);
            const [booking, deletion] = await Promise.all([
              request(
                'POST',
                '/reservations',
                { parkingSpaceId: s.id, durationMinutes: 60 },
                user,
              ),
              request('DELETE', `/admin/parkings/${p.id}`),
            ]);
            if (booking.status === 201) {
              assert.equal(deletion.status, 409);
              assert.equal(
                await db
                  .getRepository(Reservation)
                  .existsBy({ id: booking.body.id }),
                true,
              );
              assert.equal(
                await db.getRepository(ParkingSpace).existsBy({ id: s.id }),
                true,
              );
            } else {
              assert.equal(booking.status, 404);
              assert.equal(deletion.status, 204);
              assert.equal(
                await db.getRepository(ParkingSpace).existsBy({ id: s.id }),
                false,
              );
            }
          }
        },
      );
    } finally {
      if (spaceIds.length) {
        await db
          .getRepository(Reservation)
          .delete({ parkingSpaceId: In(spaceIds) });
        await db.getRepository(ParkingSpace).delete({ id: In(spaceIds) });
      }
      if (parkingIds.length)
        await db.getRepository(Parking).delete({ id: In(parkingIds) });
      if (userIds.length)
        await db.getRepository(User).delete({ id: In(userIds) });
      await app.close();
    }
  },
);
