import { ParkingSpacesModule } from './parking-spaces/parking-spaces.module';
import { ParkingModule } from './parking/parking.module';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { resolve } from 'node:path';
import { validateEnvironment } from './config/environment';
import { DatabaseModule } from './database/database.module';
import { HealthController } from './health.controller';
import { AuthModule } from './auth/auth.module';
import { ReservationsModule } from './reservations/reservations.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: resolve(__dirname, '../../.env'),
      validate: validateEnvironment,
    }),
    DatabaseModule,
    AuthModule,
    ParkingModule,
    ParkingSpacesModule,
    ReservationsModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
