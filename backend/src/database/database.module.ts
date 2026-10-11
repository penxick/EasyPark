import { CreateParkingSpaces1790553600000 } from './migrations/1790553600000-create-parking-spaces';
import { CreateParkings1790380800000 } from './migrations/1790380800000-create-parkings';
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CreateUsers1789776000000 } from './migrations/1789776000000-create-users';
import { CreateReservations1790640000000 } from './migrations/1790640000000-create-reservations';
import { AddUserLogin1791331200000 } from './migrations/1791331200000-add-user-login';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres' as const,
        host: config.getOrThrow<string>('DB_HOST'),
        port: config.getOrThrow<number>('POSTGRES_PORT'),
        database: config.getOrThrow<string>('POSTGRES_DB'),
        username: config.getOrThrow<string>('POSTGRES_USER'),
        password: config.getOrThrow<string>('POSTGRES_PASSWORD'),
        autoLoadEntities: true,
        synchronize: false,
        migrationsRun: false,
        migrations: [
          CreateUsers1789776000000,
          CreateParkings1790380800000,
          CreateParkingSpaces1790553600000,
          CreateReservations1790640000000,
          AddUserLogin1791331200000,
        ],
        retryAttempts: 3,
        retryDelay: 1000,
        connectTimeoutMS: 3000,
        extra: {
          max: 10,
          connectionTimeoutMillis: 3000,
          statement_timeout: 2000,
          query_timeout: 2500,
          application_name: 'easypark-backend',
        },
      }),
    }),
  ],
})
export class DatabaseModule {}
