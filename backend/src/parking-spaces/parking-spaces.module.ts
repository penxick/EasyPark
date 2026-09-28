import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthModule } from '../auth/auth.module';
import { Parking } from '../parking/parking.entity';
import { ParkingSpace } from './parking-space.entity';
import { ParkingSpacesService } from './parking-spaces.service';
import { ParkingSpacesController } from './parking-spaces.controller';

@Module({
  imports: [TypeOrmModule.forFeature([ParkingSpace, Parking]), AuthModule],
  providers: [ParkingSpacesService],
  controllers: [ParkingSpacesController],
})
export class ParkingSpacesModule {}
