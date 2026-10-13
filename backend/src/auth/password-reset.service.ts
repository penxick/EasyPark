import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';
import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { createTransport } from 'nodemailer';
import { PasswordService } from './password.service';

@Injectable()
export class PasswordResetService {
  constructor(
    private readonly db: DataSource,
    private readonly config: ConfigService,
    private readonly passwords: PasswordService,
  ) {}
  private digest(value: string) {
    return createHmac('sha256', this.config.getOrThrow<string>('JWT_SECRET'))
      .update(value)
      .digest('hex');
  }
  async request(email: string) {
    const host = this.config.get<string>('SMTP_HOST');
    const from = this.config.get<string>('SMTP_FROM');
    const port = Number(this.config.get('SMTP_PORT') ?? 587);
    if (!host || !from || !Number.isInteger(port) || port < 1 || port > 65535)
      throw new ServiceUnavailableException(
        'Отправка писем не настроена. Обратитесь к администратору.',
      );
    const code = String(randomInt(0, 1000000)).padStart(6, '0');
    const key = this.digest(`email:${email}`);
    const hash = this.digest(`${email}:${code}`);
    const rows: { userId: number | null }[] = await this.db.query(
      `
      INSERT INTO password_resets (key, "userId", "codeHash", "expiresAt", attempts, "requestedAt")
      VALUES ($1, (SELECT id FROM users WHERE email=$2), $3, CURRENT_TIMESTAMP + interval '10 minutes', 0, CURRENT_TIMESTAMP)
      ON CONFLICT (key) DO UPDATE SET "userId"=EXCLUDED."userId", "codeHash"=EXCLUDED."codeHash",
        "expiresAt"=EXCLUDED."expiresAt", attempts=0, "requestedAt"=EXCLUDED."requestedAt"
      WHERE password_resets."requestedAt" < CURRENT_TIMESTAMP - interval '60 seconds'
      RETURNING "userId"`,
      [key, email, hash],
    );
    if (rows[0]?.userId) {
      const user = this.config.get<string>('SMTP_USER');
      const transport = createTransport({
        host,
        port,
        secure: this.config.get('SMTP_SECURE') === 'true',
        requireTLS: this.config.get('SMTP_SECURE') !== 'true',
        connectionTimeout: 5000,
        greetingTimeout: 5000,
        socketTimeout: 5000,
        ...(user
          ? { auth: { user, pass: this.config.get<string>('SMTP_PASSWORD') } }
          : {}),
      });
      void (async () => {
        try {
          await transport.sendMail({
            from,
            to: email,
            subject: 'EasyPark — восстановление пароля',
            text: `Код восстановления EasyPark: ${code}. Действует 10 минут. Если вы не запрашивали код, проигнорируйте письмо.`,
          });
        } catch {
          // Do not disclose account existence through delivery errors or log codes.
          await this.db.query(
            'UPDATE password_resets SET "expiresAt"=CURRENT_TIMESTAMP WHERE key=$1 AND "codeHash"=$2',
            [key, hash],
          );
        } finally {
          transport.close();
        }
      })().catch(() => {
        /* No account/code details in logs or response. */
      });
    }
    return {
      message:
        'Если адрес зарегистрирован и почтовая служба доступна, вы получите код. Проверьте почту и папку «Спам».',
    };
  }
  async confirm(email: string, code: string, password: string) {
    const hash = await this.passwords.hash(password);
    const key = this.digest(`email:${email}`);
    const valid = await this.db.transaction(async (manager) => {
      const rows: {
        userId: number | null;
        codeHash: string;
        expiresAt: Date;
        attempts: number;
      }[] = await manager.query(
        'SELECT * FROM password_resets WHERE key=$1 FOR UPDATE',
        [key],
      );
      const row = rows[0];
      if (!row || row.attempts >= 5 || new Date(row.expiresAt) <= new Date())
        return false;
      await manager.query(
        'UPDATE password_resets SET attempts=attempts+1 WHERE key=$1',
        [key],
      );
      const matches = timingSafeEqual(
        Buffer.from(row.codeHash, 'hex'),
        Buffer.from(this.digest(`${email}:${code}`), 'hex'),
      );
      if (!matches || !row.userId) return false;
      await manager.query(
        'UPDATE users SET "passwordHash"=$1, "tokenVersion"="tokenVersion"+1, "updatedAt"=CURRENT_TIMESTAMP WHERE id=$2',
        [hash, row.userId],
      );
      await manager.query(
        'UPDATE password_resets SET attempts=5, "expiresAt"=CURRENT_TIMESTAMP WHERE key=$1',
        [key],
      );
      return true;
    });
    if (!valid)
      throw new BadRequestException(
        'Код недействителен или срок его действия истёк.',
      );
    return { message: 'Пароль изменён. Войдите с новым паролем.' };
  }
}
