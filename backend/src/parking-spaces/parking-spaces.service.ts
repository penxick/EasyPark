import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Parking } from '../parking/parking.entity';
import { ParkingSpace } from './parking-space.entity';

@Injectable()
export class ParkingSpacesService {
  constructor(
    @InjectRepository(ParkingSpace)
    private readonly spaces: Repository<ParkingSpace>,
    @InjectRepository(Parking) private readonly parkings: Repository<Parking>,
  ) {}
  async findByParking(parkingId: number): Promise<ParkingSpace[]> {
    if (!(await this.parkings.existsBy({ id: parkingId })))
      throw new NotFoundException('Парковка не найдена.');
    return this.spaces.find({
      where: { parkingId },
      order: { code: 'ASC', id: 'ASC' },
    });
  }
}
