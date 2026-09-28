import { MigrationInterface, QueryRunner } from 'typeorm';
export class CreateParkingSpaces1790553600000 implements MigrationInterface {
  name = 'CreateParkingSpaces1790553600000';
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`CREATE TABLE "parking_spaces" (
      "id" SERIAL NOT NULL,
      "parkingId" integer NOT NULL,
      "code" varchar(20) NOT NULL,
      "status" varchar(11) NOT NULL DEFAULT 'FREE',
      "physicalOccupied" boolean NOT NULL DEFAULT false,
      "x" double precision NOT NULL,
      "y" double precision NOT NULL,
      "polygon" jsonb,
      "createdAt" timestamptz NOT NULL DEFAULT now(),
      "updatedAt" timestamptz NOT NULL DEFAULT now(),
      CONSTRAINT "PK_parking_spaces_id" PRIMARY KEY ("id"),
      CONSTRAINT "FK_parking_spaces_parking" FOREIGN KEY ("parkingId") REFERENCES "parkings"("id") ON DELETE RESTRICT,
      CONSTRAINT "CHK_parking_spaces_status" CHECK ("status" IN ('FREE', 'OCCUPIED', 'RESERVED', 'UNAVAILABLE')),
      CONSTRAINT "CHK_parking_spaces_code" CHECK ("code" = btrim("code") AND length("code") > 0),
      CONSTRAINT "CHK_parking_spaces_x" CHECK ("x" >= 0 AND "x" < 'Infinity'::float8),
      CONSTRAINT "CHK_parking_spaces_y" CHECK ("y" >= 0 AND "y" < 'Infinity'::float8),
      CONSTRAINT "CHK_parking_spaces_polygon" CHECK ("polygon" IS NULL OR (jsonb_typeof("polygon") = 'array' AND jsonb_array_length("polygon") >= 3))
    )`);
    await runner.query(
      'CREATE UNIQUE INDEX "UQ_parking_spaces_code" ON "parking_spaces" ("parkingId", "code")',
    );
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query('DROP TABLE "parking_spaces"');
  }
}
