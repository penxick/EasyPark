import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Parking } from './parking.entity';
import { ParkingSpace } from '../parking-spaces/parking-space.entity';

@Injectable()
export class ParkingService {
  constructor(
    @InjectRepository(Parking) private readonly parkings: Repository<Parking>,
  ) {}
  private withCounts() {
    return this.parkings
      .createQueryBuilder('parking')
      .addSelect(
        (query) =>
          query
            .select('COUNT(*)::int')
            .from(ParkingSpace, 'space')
            .where('space.parkingId = parking.id'),
        'totalSpaces',
      )
      .addSelect(
        (query) =>
          query
            .select('COUNT(*)::int')
            .from(ParkingSpace, 'space')
            .where('space.parkingId = parking.id')
            .andWhere('space.status = :free', { free: 'FREE' })
            .andWhere('space.physicalOccupied = false'),
        'freeSpaces',
      );
  }
  async findAll() {
    const { entities, raw } = await this.withCounts()
      .orderBy('parking.id', 'ASC')
      .getRawAndEntities<{ freeSpaces: number; totalSpaces: number }>();
    return entities.map((parking, index) => ({
      ...parking,
      freeSpaces: raw[index].freeSpaces,
      totalSpaces: raw[index].totalSpaces,
    }));
  }
  async findOne(id: number) {
    const { entities, raw } = await this.withCounts()
      .where('parking.id = :id', { id })
      .getRawAndEntities<{ freeSpaces: number; totalSpaces: number }>();
    if (!entities[0]) throw new NotFoundException('Парковка не найдена.');
    return {
      ...entities[0],
      freeSpaces: raw[0].freeSpaces,
      totalSpaces: raw[0].totalSpaces,
    };
  }
}
