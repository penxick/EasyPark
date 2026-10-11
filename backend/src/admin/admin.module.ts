import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ParkingModule } from '../parking/parking.module';
import { AdminParkingController } from './admin-parking.controller';
import { ParkingSpacesModule } from '../parking-spaces/parking-spaces.module';
import { AdminSpacesController } from './admin-spaces.controller';
import { AdminReadController } from './admin-read.controller';
import { ReservationsModule } from '../reservations/reservations.module';
import { AdminAnalyticsController } from './admin-analytics.controller';
import { AdminAnalyticsService } from './admin-analytics.service';

@Module({
  imports: [AuthModule, ParkingModule, ParkingSpacesModule, ReservationsModule],
  controllers: [
    AdminParkingController,
    AdminSpacesController,
    AdminReadController,
    AdminAnalyticsController,
  ],
  providers: [AdminAnalyticsService],
})
export class AdminModule {}
