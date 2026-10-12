import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddParkingPrice301791763200000 implements MigrationInterface {
  name = 'AddParkingPrice301791763200000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "parkings" ADD "pricePer30Min" numeric(10,2) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "parkings" ADD CONSTRAINT "CHK_parkings_price30" CHECK ("pricePer30Min" >= 0 AND "pricePer30Min" <= 99999999.99)`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "parkings" DROP CONSTRAINT "CHK_parkings_price30"`,
    );
    await queryRunner.query(
      `ALTER TABLE "parkings" DROP COLUMN "pricePer30Min"`,
    );
  }
}
