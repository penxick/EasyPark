import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateUsers1789776000000 implements MigrationInterface {
  name = 'CreateUsers1789776000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE "users" (
      "id" SERIAL NOT NULL,
      "name" varchar(100) NOT NULL,
      "email" varchar(254) NOT NULL,
      "passwordHash" varchar(255) NOT NULL,
      "role" varchar(5) NOT NULL DEFAULT 'USER',
      "createdAt" timestamptz NOT NULL DEFAULT now(),
      "updatedAt" timestamptz NOT NULL DEFAULT now(),
      CONSTRAINT "PK_users_id" PRIMARY KEY ("id"),
      CONSTRAINT "CHK_users_email_normalized" CHECK ("email" = lower(btrim("email"))),
      CONSTRAINT "CHK_users_role" CHECK ("role" IN ('USER', 'ADMIN'))
    )`);
    await queryRunner.query(
      'CREATE UNIQUE INDEX "UQ_users_email" ON "users" ("email")',
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE "users"');
  }
}
