import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, Repository } from 'typeorm';
import { Parking } from './parking.entity';
import { ParkingSpace } from '../parking-spaces/parking-space.entity';
import { Reservation } from '../reservations/reservation.entity';
import { CreateParkingDto, UpdateParkingDto } from './parking.dto';

@Injectable()
export class ParkingService {
  constructor(
    @InjectRepository(Parking) private readonly parkings: Repository<Parking>,
  ) {}

  async create(dto: CreateParkingDto) {
    const parking = await this.parkings.save(this.parkings.create(dto));
    return this.findOne(parking.id);
  }

  async update(id: number, dto: UpdateParkingDto) {
    if (!Object.values(dto).some((value) => value !== undefined)) {
      throw new BadRequestException('Укажите хотя бы одно поле для изменения.');
    }
    // A partial UPDATE preserves concurrent changes to other fields.
    const result = await this.parkings.update(id, dto);
    if (!result.affected) throw new NotFoundException('Парковка не найдена.');
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    try {
      await this.parkings.manager.transaction(async (manager) => {
        // Parent lock prevents concurrent insertion of children through their FK.
        const parking = await manager.findOne(Parking, {
          where: { id },
          lock: { mode: 'pessimistic_write' },
        });
        if (!parking) throw new NotFoundException('Парковка не найдена.');
        // Reservations also lock the space first. Wait for in-flight bookings,
        // then inspect history using a new READ COMMITTED snapshot.
        await manager
          .getRepository(ParkingSpace)
          .createQueryBuilder('space')
          .where('space.parkingId = :id', { id })
          .orderBy('space.id', 'ASC')
          .setLock('pessimistic_write')
          .getMany();
        const hasHistory = await manager
          .getRepository(Reservation)
          .createQueryBuilder('reservation')
          .innerJoin('reservation.parkingSpace', 'space')
          .where('space.parkingId = :id', { id })
          .getExists();
        if (hasHistory) {
          throw new ConflictException({
            code: 'PARKING_HAS_RESERVATIONS',
            message: 'Нельзя удалить парковку с историей бронирований.',
          });
        }
        await manager.delete(ParkingSpace, { parkingId: id });
        await manager.delete(Parking, id);
      });
    } catch (error) {
      if (error instanceof QueryFailedError) {
        const code = (error.driverError as { code?: string }).code;
        if (code === '23503') {
          throw new ConflictException({
            code: 'PARKING_HAS_RELATED_DATA',
            message:
              'Парковка содержит связанные данные и не может быть удалена.',
          });
        }
        if (['40P01', '55P03', '57014'].includes(code ?? '')) {
          throw new ConflictException({
            code: 'PARKING_BUSY',
            message: 'Данные парковки сейчас изменяются. Повторите попытку.',
          });
        }
      }
      throw error;
    }
  }
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
