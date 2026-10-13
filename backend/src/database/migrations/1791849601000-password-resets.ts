import { MigrationInterface, QueryRunner } from 'typeorm';
export class PasswordResets1791849601000 implements MigrationInterface {
  name = 'PasswordResets1791849601000';
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      'ALTER TABLE users ADD COLUMN "tokenVersion" integer NOT NULL DEFAULT 0',
    );
    await q.query(`CREATE TABLE password_resets (
      key varchar(64) PRIMARY KEY, "userId" integer REFERENCES users(id) ON DELETE CASCADE,
      "codeHash" varchar(64) NOT NULL, "expiresAt" timestamptz NOT NULL,
      attempts integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
      "requestedAt" timestamptz NOT NULL)`);
  }
  async down(q: QueryRunner): Promise<void> {
    await q.query('DROP TABLE password_resets');
    await q.query('ALTER TABLE users DROP COLUMN "tokenVersion"');
  }
}
