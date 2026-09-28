import { Injectable } from '@nestjs/common';
import { randomBytes, scrypt, timingSafeEqual } from 'node:crypto';

const PREFIX = 'scrypt$32768$8$3$';
// Equal-cost password check for unknown users; this is not an account hash.
export const DUMMY_PASSWORD_HASH = `${PREFIX}${'00'.repeat(16)}$${'00'.repeat(64)}`;

@Injectable()
export class PasswordService {
  private derive(password: string, salt: Buffer): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      scrypt(
        password,
        salt,
        64,
        { N: 32768, r: 8, p: 3, maxmem: 64 * 1024 * 1024 },
        (error, key) => (error ? reject(error) : resolve(key)),
      );
    });
  }

  async hash(password: string): Promise<string> {
    const salt = randomBytes(16);
    const key = await this.derive(password, salt);
    return `${PREFIX}${salt.toString('hex')}$${key.toString('hex')}`;
  }

  async verify(password: string, encoded: string): Promise<boolean> {
    if (!/^scrypt\$32768\$8\$3\$[a-f0-9]{32}\$[a-f0-9]{128}$/.test(encoded))
      return false;
    const parts = encoded.split('$');
    const actual = await this.derive(password, Buffer.from(parts[4], 'hex'));
    return timingSafeEqual(actual, Buffer.from(parts[5], 'hex'));
  }
}
