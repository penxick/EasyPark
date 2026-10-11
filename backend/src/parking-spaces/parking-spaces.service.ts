import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import {
  EntityManager,
  In,
  MoreThan,
  QueryFailedError,
  Repository,
} from 'typeorm';
import { Parking } from '../parking/parking.entity';
import { ParkingSpace, ParkingSpaceStatus } from './parking-space.entity';
import {
  CreateParkingSpaceDto,
  UpdateParkingSpaceDto,
} from './parking-space.dto';
import {
  Reservation,
  ReservationStatus,
} from '../reservations/reservation.entity';
import { ReservationsService } from '../reservations/reservations.service';

@Injectable()
export class ParkingSpacesService {
  constructor(
    @InjectRepository(ParkingSpace)
    private readonly spaces: Repository<ParkingSpace>,
    @InjectRepository(Parking) private readonly parkings: Repository<Parking>,
    private readonly reservations: ReservationsService,
  ) {}
  async findByParking(parkingId: number) {
    if (!(await this.parkings.existsBy({ id: parkingId })))
      throw new NotFoundException('Парковка не найдена.');
    const { entities, raw } = await this.spaces
      .createQueryBuilder('space')
      .addSelect(
        (query) =>
          query
            .select('COUNT(*) > 0')
            .from(Reservation, 'reservation')
            .where('reservation.parkingSpaceId = space.id')
            .andWhere('reservation.status IN (:...live)', {
              live: [ReservationStatus.ACTIVE, ReservationStatus.PENDING],
            })
            .andWhere('reservation.endTime > CURRENT_TIMESTAMP'),
        'hasActiveReservation',
      )
      .where('space.parkingId = :parkingId', { parkingId })
      .orderBy('space.code', 'ASC')
      .addOrderBy('space.id', 'ASC')
      .getRawAndEntities<{ hasActiveReservation: boolean }>();
    return entities.map((space, index) => ({
      ...space,
      hasActiveReservation: raw[index].hasActiveReservation,
    }));
  }

  private hasActiveReservation(manager: EntityManager, id: number, now: Date) {
    return manager.existsBy(Reservation, {
      parkingSpaceId: id,
      status: In([ReservationStatus.ACTIVE, ReservationStatus.PENDING]),
      endTime: MoreThan(now),
    });
  }

  private async lock(manager: EntityManager, id: number) {
    const space = await manager.findOne(ParkingSpace, {
      where: { id },
      lock: { mode: 'pessimistic_write' },
    });
    if (!space) throw new NotFoundException('Место не найдено.');
    return space;
  }

  private async mutation<T>(
    operation: (manager: EntityManager) => Promise<T>,
  ): Promise<T> {
    try {
      return await this.spaces.manager.transaction(operation);
    } catch (error) {
      if (error instanceof QueryFailedError) {
        const { code, constraint } = error.driverError as {
          code?: string;
          constraint?: string;
        };
        if (code === '23505' && constraint === 'UQ_parking_spaces_code') {
          throw new ConflictException({
            code: 'SPACE_CODE_EXISTS',
            message: 'Парковочное место с таким кодом уже существует.',
          });
        }
        if (code === '23503') {
          throw new ConflictException({
            code: 'SPACE_HAS_RELATED_DATA',
            message: 'Операция невозможна: связанные данные места изменились.',
          });
        }
        if (['40P01', '55P03', '57014'].includes(code ?? '')) {
          throw new ConflictException({
            code: 'SPACE_BUSY',
            message: 'Место сейчас изменяется. Повторите попытку.',
          });
        }
      }
      throw error;
    }
  }

  create(parkingId: number, dto: CreateParkingSpaceDto) {
    return this.mutation(async (manager) => {
      const parking = await manager.findOne(Parking, {
        where: { id: parkingId },
        lock: { mode: 'pessimistic_read' },
      });
      if (!parking) throw new NotFoundException('Парковка не найдена.');
      const space = await manager.save(
        ParkingSpace,
        manager.create(ParkingSpace, {
          parkingId,
          ...dto,
          status: ParkingSpaceStatus.FREE,
          physicalOccupied: false,
        }),
      );
      return { ...space, hasActiveReservation: false };
    });
  }

  update(id: number, dto: UpdateParkingSpaceDto) {
    if (!Object.values(dto).some((value) => value !== undefined)) {
      throw new BadRequestException('Укажите хотя бы одно поле для изменения.');
    }
    return this.mutation(async (manager) => {
      const space = await this.lock(manager, id);
      const now = new Date();
      if (dto.available !== undefined)
        await this.reservations.expireLockedSpace(manager, space, now);
      const hasActiveReservation = await this.hasActiveReservation(
        manager,
        id,
        now,
      );
      if (dto.code !== undefined) space.code = dto.code;
      if (dto.x !== undefined) space.x = dto.x;
      if (dto.y !== undefined) space.y = dto.y;
      if (dto.polygon !== undefined) space.polygon = dto.polygon;
      if (dto.available !== undefined) {
        space.status = !dto.available
          ? ParkingSpaceStatus.UNAVAILABLE
          : hasActiveReservation
            ? ParkingSpaceStatus.RESERVED
            : space.physicalOccupied
              ? ParkingSpaceStatus.OCCUPIED
              : ParkingSpaceStatus.FREE;
      }
      // Never accept or overwrite physicalOccupied from the administrative DTO.
      return { ...(await manager.save(space)), hasActiveReservation };
    });
  }

  async remove(id: number): Promise<void> {
    await this.mutation(async (manager) => {
      await this.lock(manager, id);
      if (await manager.existsBy(Reservation, { parkingSpaceId: id })) {
        throw new ConflictException({
          code: 'SPACE_HAS_RESERVATIONS',
          message: 'Нельзя удалить место с историей бронирований.',
        });
      }
      await manager.delete(ParkingSpace, id);
    });
  }
}
