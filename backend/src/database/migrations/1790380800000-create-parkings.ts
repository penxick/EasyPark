import { MigrationInterface, QueryRunner } from 'typeorm';
export class CreateParkings1790380800000 implements MigrationInterface {
  name = 'CreateParkings1790380800000';
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`CREATE TABLE "parkings" (
      "id" SERIAL NOT NULL,
      "name" varchar(200) NOT NULL,
      "description" text NOT NULL,
      "address" varchar(500) NOT NULL,
      "latitude" numeric(9,6) NOT NULL,
      "longitude" numeric(9,6) NOT NULL,
      "pricePerHour" numeric(10,2) NOT NULL,
      "workingHours" varchar(200) NOT NULL,
      "createdAt" timestamptz NOT NULL DEFAULT now(),
      "updatedAt" timestamptz NOT NULL DEFAULT now(),
      CONSTRAINT "PK_parkings_id" PRIMARY KEY ("id"),
      CONSTRAINT "CHK_parkings_latitude" CHECK ("latitude" BETWEEN -90 AND 90),
      CONSTRAINT "CHK_parkings_longitude" CHECK ("longitude" BETWEEN -180 AND 180),
      CONSTRAINT "CHK_parkings_price" CHECK ("pricePerHour" >= 0 AND "pricePerHour" <= 99999999.99)
    )`);
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query('DROP TABLE "parkings"');
  }
}
