function requiredText(config: Record<string, unknown>, key: string): string {
  const value = config[key];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`${key} must be a non-empty string`);
  }
  return value;
}

function port(value: unknown, key: string): number {
  if (!/^\d+$/.test(String(value))) {
    throw new Error(`${key} must be an integer between 1 and 65535`);
  }
  const number = Number(value);
  if (number < 1 || number > 65535) {
    throw new Error(`${key} must be an integer between 1 and 65535`);
  }
  return number;
}

export function validateEnvironment(config: Record<string, unknown>) {
  const secret = requiredText(config, 'JWT_SECRET');
  if (
    Buffer.byteLength(secret, 'utf8') < 32 ||
    /change.?me|replace|example/i.test(secret)
  ) {
    throw new Error(
      'JWT_SECRET must be a random secret of at least 32 bytes, not a placeholder',
    );
  }
  const ttl = String(config.JWT_TTL_SECONDS ?? 604800);
  const adminLogin = requiredText(config, 'ADMIN_LOGIN').trim().toLowerCase();
  if (!/^[a-z][a-z0-9_.-]{0,63}$/.test(adminLogin)) {
    throw new Error(
      'ADMIN_LOGIN must contain 1..64 ASCII letters, digits, dot, underscore or hyphen and start with a letter',
    );
  }
  const adminPassword = requiredText(config, 'ADMIN_PASSWORD');
  if (
    adminPassword.length < 12 ||
    adminPassword.length > 128 ||
    /change.?me|replace|example/i.test(adminPassword)
  ) {
    throw new Error(
      'ADMIN_PASSWORD must contain 12..128 characters and must not be a placeholder',
    );
  }
  if (!/^\d+$/.test(ttl) || Number(ttl) < 60 || Number(ttl) > 2592000) {
    throw new Error(
      'JWT_TTL_SECONDS must be an integer between 60 and 2592000',
    );
  }
  return {
    ADMIN_LOGIN: adminLogin,
    ADMIN_PASSWORD: adminPassword,
    JWT_SECRET: secret,
    JWT_TTL_SECONDS: Number(ttl),
    PORT: port(config.PORT ?? config.BACKEND_PORT ?? 3000, 'PORT'),
    DB_HOST: requiredText(
      { DB_HOST: config.DB_HOST ?? '127.0.0.1' },
      'DB_HOST',
    ),
    POSTGRES_PORT: port(config.POSTGRES_PORT ?? 55432, 'POSTGRES_PORT'),
    POSTGRES_DB: requiredText(config, 'POSTGRES_DB'),
    POSTGRES_USER: requiredText(config, 'POSTGRES_USER'),
    POSTGRES_PASSWORD: requiredText(config, 'POSTGRES_PASSWORD'),
  };
}
