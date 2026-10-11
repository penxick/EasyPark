import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';
import { User, UserRole } from '../users/user.entity';
import { PasswordService } from './password.service';

export const SYSTEM_ADMIN_EMAIL = 'admin@easypark.invalid';

@Injectable()
export class AdminBootstrapService {
  constructor(
    private readonly db: DataSource,
    private readonly config: ConfigService,
    private readonly passwords: PasswordService,
  ) {}

  // Called by HTTP bootstrap only, after the migration command has finished.
  async ensureAdmin(): Promise<void> {
    const login = this.config.getOrThrow<string>('ADMIN_LOGIN');
    const password = this.config.getOrThrow<string>('ADMIN_PASSWORD');
    await this.db.transaction(async (manager) => {
      await manager.query('SELECT pg_advisory_xact_lock(1791331200)');
      const users = manager.getRepository(User);
      const existing = await users.find({
        where: [{ login }, { email: SYSTEM_ADMIN_EMAIL }],
      });
      if (existing.length > 0) {
        if (
          existing.length !== 1 ||
          existing[0].role !== UserRole.ADMIN ||
          existing[0].login !== login ||
          existing[0].email !== SYSTEM_ADMIN_EMAIL
        ) {
          throw new Error(
            'System administrator identity conflict; existing users were not changed.',
          );
        }
        return; // Never reset an existing password or promote a USER on startup.
      }
      await users.save(
        users.create({
          name: 'Администратор',
          email: SYSTEM_ADMIN_EMAIL,
          login,
          role: UserRole.ADMIN,
          passwordHash: await this.passwords.hash(password),
        }),
      );
    });
  }
}
