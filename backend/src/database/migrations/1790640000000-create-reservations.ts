import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateReservations1790640000000 implements MigrationInterface {
  name = 'CreateReservations1790640000000';
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`CREATE TABLE "reservations" (
      "id" SERIAL NOT NULL,
      "userId" integer NOT NULL,
      "parkingSpaceId" integer NOT NULL,
      "startTime" timestamptz NOT NULL,
      "endTime" timestamptz NOT NULL,
      "status" varchar(9) NOT NULL DEFAULT 'ACTIVE',
      "totalPrice" numeric(12,2) NOT NULL,
      "createdAt" timestamptz NOT NULL DEFAULT now(),
      "updatedAt" timestamptz NOT NULL DEFAULT now(),
      CONSTRAINT "PK_reservations_id" PRIMARY KEY ("id"),
      CONSTRAINT "FK_reservations_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT,
      CONSTRAINT "FK_reservations_space" FOREIGN KEY ("parkingSpaceId") REFERENCES "parking_spaces"("id") ON DELETE RESTRICT,
      CONSTRAINT "CHK_reservations_status" CHECK ("status" IN ('PENDING', 'ACTIVE', 'COMPLETED', 'CANCELLED', 'EXPIRED')),
      CONSTRAINT "CHK_reservations_time" CHECK (isfinite("startTime") AND isfinite("endTime") AND "endTime" > "startTime"),
      CONSTRAINT "CHK_reservations_price" CHECK ("totalPrice" >= 0 AND "totalPrice" <= 9999999999.99)
    )`);
    await runner.query(
      `CREATE UNIQUE INDEX "UQ_reservations_live_space" ON "reservations" ("parkingSpaceId") WHERE "status" IN ('PENDING', 'ACTIVE')`,
    );
    await runner.query(
      'CREATE INDEX "IDX_reservations_user" ON "reservations" ("userId")',
    );
    await runner.query(
      `CREATE INDEX "IDX_reservations_expiry" ON "reservations" ("endTime") WHERE "status" IN ('PENDING', 'ACTIVE')`,
    );
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query('DROP TABLE "reservations"');
  }
}
