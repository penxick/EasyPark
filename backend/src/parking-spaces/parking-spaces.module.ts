import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Parking } from '../parking/parking.entity';
import { ParkingSpace } from './parking-space.entity';
import { ParkingSpacesService } from './parking-spaces.service';
import { ParkingSpacesController } from './parking-spaces.controller';
import { ReservationsModule } from '../reservations/reservations.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([ParkingSpace, Parking]),
    AuthModule,
    ReservationsModule,
  ],
  providers: [ParkingSpacesService],
  exports: [ParkingSpacesService],
  controllers: [ParkingSpacesController],
})
export class ParkingSpacesModule {}
