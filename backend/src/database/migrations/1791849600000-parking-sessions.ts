import { MigrationInterface, QueryRunner } from 'typeorm';

export class ParkingSessions1791849600000 implements MigrationInterface {
  name = 'ParkingSessions1791849600000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE reservations
      ADD COLUMN "mode" varchar(7),
      ADD COLUMN "sessionState" varchar(20),
      ADD COLUMN "paymentMethod" varchar(4),
      ADD COLUMN "paymentStatus" varchar(20),
      ADD COLUMN "plannedMinutes" integer,
      ADD COLUMN "hourlyRateSnapshot" numeric(10,2),
      ADD COLUMN "preliminaryPrice" numeric(12,2),
      ADD COLUMN "finalPrice" numeric(12,2),
      ADD COLUMN "actualStartTime" timestamptz,
      ADD COLUMN "actualEndTime" timestamptz,
      ADD COLUMN "actualSeconds" integer,
      ADD CONSTRAINT "CHK_session_fields" CHECK (mode IS NULL OR (
        mode IN ('PLANNED','METERED') AND "sessionState" IS NOT NULL AND
        "sessionState" IN ('WAITING_ARRIVAL','PARKED','WAITING_DEPARTURE','FINISHED','CANCELLED') AND
        "paymentMethod" IS NOT NULL AND "paymentMethod" IN ('CARD','SBP') AND
        "paymentStatus" IS NOT NULL AND "paymentStatus" IN ('DEMO_PENDING','DEMO_CONFIRMED') AND
        "hourlyRateSnapshot" IS NOT NULL AND "hourlyRateSnapshot" >= 0 AND
        ((mode='PLANNED' AND "plannedMinutes" BETWEEN 1 AND 1440 AND "preliminaryPrice" >= 0)
         OR (mode='METERED' AND "plannedMinutes" IS NULL AND "preliminaryPrice" IS NULL))
      )),
      ADD CONSTRAINT "CHK_session_actual" CHECK (
        ("actualSeconds" IS NULL OR "actualSeconds" >= 0) AND
        ("finalPrice" IS NULL OR "finalPrice" >= 0) AND
        ("actualEndTime" IS NULL OR ("actualStartTime" IS NOT NULL AND "actualEndTime" >= "actualStartTime")))`);
  }
  async down(q: QueryRunner): Promise<void> {
    // Never silently discard recorded sessions on rollback.
    const [row] = await q.query(
      `SELECT count(*)::int AS n FROM reservations WHERE mode IS NOT NULL`,
    );
    if (row.n) throw new Error('Cannot roll back while parking sessions exist');
    await q.query(`ALTER TABLE reservations DROP CONSTRAINT "CHK_session_fields", DROP CONSTRAINT "CHK_session_actual",
      DROP COLUMN mode, DROP COLUMN "sessionState", DROP COLUMN "paymentMethod", DROP COLUMN "paymentStatus",
      DROP COLUMN "plannedMinutes", DROP COLUMN "hourlyRateSnapshot", DROP COLUMN "preliminaryPrice", DROP COLUMN "finalPrice",
      DROP COLUMN "actualStartTime", DROP COLUMN "actualEndTime", DROP COLUMN "actualSeconds"`);
  }
}
