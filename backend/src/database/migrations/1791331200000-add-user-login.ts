import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUserLogin1791331200000 implements MigrationInterface {
  name = 'AddUserLogin1791331200000';

  async up(runner: QueryRunner): Promise<void> {
    await runner.query('ALTER TABLE "users" ADD "login" varchar(64)');
    await runner.query(`ALTER TABLE "users" ADD CONSTRAINT "CHK_users_login_format"
      CHECK ("login" IS NULL OR "login" ~ '^[a-z][a-z0-9_.-]{0,63}$')`);
    await runner.query(
      'CREATE UNIQUE INDEX "UQ_users_login" ON "users" ("login")',
    );
  }

  async down(runner: QueryRunner): Promise<void> {
    await runner.query('ALTER TABLE "users" DROP COLUMN "login"');
  }
}
