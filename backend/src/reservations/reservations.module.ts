import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { ParkingSpace } from '../parking-spaces/parking-space.entity';
import { Parking } from '../parking/parking.entity';
import { Reservation } from './reservation.entity';
import { ReservationsService } from './reservations.service';
import { ReservationsController } from './reservations.controller';
import { ReservationExpiryWorker } from './reservation-expiry.worker';

@Module({
  imports: [
    AuthModule,
    TypeOrmModule.forFeature([Reservation, ParkingSpace, Parking]),
  ],
  providers: [ReservationsService, ReservationExpiryWorker],
  controllers: [ReservationsController],
})
export class ReservationsModule {}
