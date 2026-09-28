const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Client } = require('pg');

async function main() {
  process.loadEnvFile('../.env');
  const db = new Client({
    host: '127.0.0.1',
    port: Number(process.env.POSTGRES_PORT),
    database: process.env.POSTGRES_DB,
    user: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
  });
  const email = `stage7-smoke-${randomUUID()}@example.com`;
  await db.connect();
  try {
    assert.equal((await fetch('http://localhost:3000/health')).status, 200);
    const registered = await fetch('http://localhost:3000/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Parking smoke',
        email,
        password: randomUUID(),
      }),
    });
    assert.equal(registered.status, 201);
    const { accessToken } = await registered.json();
    const headers = { Authorization: `Bearer ${accessToken}` };
    const response = await fetch('http://localhost:3000/api/parkings', {
      headers,
    });
    assert.equal(response.status, 200);
    const parkings = await response.json();
    assert.equal(parkings.filter((p) => p.name.startsWith('Демо —')).length, 3);
    const detail = await fetch(
      `http://localhost:3000/api/parkings/${parkings[0].id}`,
      { headers },
    );
    assert.equal(detail.status, 200);
    assert.deepEqual(await detail.json(), parkings[0]);
    for (const parking of parkings.filter((p) => p.name.startsWith('Демо —'))) {
      const url = `http://localhost:3000/api/parkings/${parking.id}/spaces`;
      assert.equal((await fetch(url)).status, 401);
      const response = await fetch(url, { headers });
      assert.equal(response.status, 200);
      const spaces = await response.json();
      assert.equal(spaces.length, 20);
      assert.equal(parking.totalSpaces, spaces.length);
      assert.equal(
        parking.freeSpaces,
        spaces.filter((s) => s.status === 'FREE' && !s.physicalOccupied).length,
      );
      assert.deepEqual([...new Set(spaces.map((s) => s.status))].sort(), [
        'FREE',
        'OCCUPIED',
        'RESERVED',
        'UNAVAILABLE',
      ]);
    }
    assert.equal(
      (await fetch('http://localhost:3000/api/parkings')).status,
      401,
    );
    console.log(
      'Docker Parking/Space API smoke passed; three demo parkings and 60 spaces available.',
    );
  } finally {
    await db.query('DELETE FROM users WHERE email=$1', [email]);
    await db.end();
  }
}
void main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
