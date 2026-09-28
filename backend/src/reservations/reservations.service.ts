import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  DataSource,
  EntityManager,
  In,
  LessThanOrEqual,
  QueryFailedError,
} from 'typeorm';
import {
  ParkingSpace,
  ParkingSpaceStatus,
} from '../parking-spaces/parking-space.entity';
import { Parking } from '../parking/parking.entity';
import { Reservation, ReservationStatus } from './reservation.entity';
import { CreateReservationDto } from './reservation.dto';

const live = [ReservationStatus.ACTIVE, ReservationStatus.PENDING];

@Injectable()
export class ReservationsService {
  constructor(private readonly db: DataSource) {}

  // Every mutation takes the space lock first, then changes its reservations.
  private lockSpace(manager: EntityManager, id: number) {
    return manager.findOne(ParkingSpace, {
      where: { id },
      lock: { mode: 'pessimistic_write' },
    });
  }

  private async release(manager: EntityManager, space: ParkingSpace) {
    if (space.status !== ParkingSpaceStatus.RESERVED) return;
    if (
      await manager.existsBy(Reservation, {
        parkingSpaceId: space.id,
        status: In(live),
      })
    )
      return;
    space.status = space.physicalOccupied
      ? ParkingSpaceStatus.OCCUPIED
      : ParkingSpaceStatus.FREE;
    await manager.save(space);
  }

  private async expire(manager: EntityManager, space: ParkingSpace, now: Date) {
    const ended = await manager.findBy(Reservation, {
      parkingSpaceId: space.id,
      status: In(live),
      endTime: LessThanOrEqual(now),
    });
    for (const reservation of ended) {
      reservation.status =
        reservation.status === ReservationStatus.ACTIVE
          ? ReservationStatus.COMPLETED
          : ReservationStatus.EXPIRED;
      await manager.save(reservation);
    }
    if (ended.length) await this.release(manager, space);
  }

  async create(userId: number, dto: CreateReservationDto) {
    try {
      return await this.db.transaction(async (manager) => {
        const space = await this.lockSpace(manager, dto.parkingSpaceId);
        if (!space) throw new NotFoundException('Место не найдено.');
        const now = new Date();
        await this.expire(manager, space, now);
        if (
          space.status !== ParkingSpaceStatus.FREE ||
          space.physicalOccupied ||
          (await manager.existsBy(Reservation, {
            parkingSpaceId: space.id,
            status: In(live),
          }))
        ) {
          throw new ConflictException('Место уже недоступно для бронирования.');
        }
        const parking = await manager.findOneByOrFail(Parking, {
          id: space.parkingId,
        });
        // Integer kopecks; round a half-kopeck upward for the 30-minute tariff.
        const totalPrice =
          Math.round(
            (Math.round(parking.pricePerHour * 100) * dto.durationMinutes) / 60,
          ) / 100;
        const reservation = await manager.save(
          Reservation,
          manager.create(Reservation, {
            userId,
            parkingSpaceId: space.id,
            startTime: now,
            endTime: new Date(now.getTime() + dto.durationMinutes * 60000),
            status: ReservationStatus.ACTIVE,
            totalPrice,
          }),
        );
        space.status = ParkingSpaceStatus.RESERVED;
        await manager.save(space);
        return reservation;
      });
    } catch (error) {
      if (
        error instanceof QueryFailedError &&
        (error.driverError as { code?: string; constraint?: string }).code ===
          '23505' &&
        (error.driverError as { constraint?: string }).constraint ===
          'UQ_reservations_live_space'
      ) {
        throw new ConflictException('Место уже недоступно для бронирования.');
      }
      throw error;
    }
  }

  async mine(userId: number) {
    const active = await this.db.getRepository(Reservation).findBy({
      userId,
      status: In(live),
      endTime: LessThanOrEqual(new Date()),
    });
    for (const reservation of active)
      await this.expireSpace(reservation.parkingSpaceId);
    return this.db
      .getRepository(Reservation)
      .find({ where: { userId }, order: { createdAt: 'DESC', id: 'DESC' } });
  }

  async cancel(userId: number, id: number) {
    const found = await this.db
      .getRepository(Reservation)
      .findOneBy({ id, userId });
    if (!found) throw new NotFoundException('Бронирование не найдено.');
    const result = await this.db.transaction(async (manager) => {
      const space = await this.lockSpace(manager, found.parkingSpaceId);
      if (!space) throw new NotFoundException('Место не найдено.');
      await this.expire(manager, space, new Date());
      const reservation = await manager.findOneByOrFail(Reservation, {
        id,
        userId,
      });
      if (reservation.status === ReservationStatus.CANCELLED)
        return reservation;
      if (!live.includes(reservation.status)) return null;
      reservation.status = ReservationStatus.CANCELLED;
      await manager.save(reservation);
      await this.release(manager, space);
      return reservation;
    });
    // Keep the expiration committed even if cancellation is no longer allowed.
    if (!result) throw new ConflictException('Это бронирование уже завершено.');
    return result;
  }

  private async expireSpace(id: number) {
    await this.db.transaction(async (manager) => {
      const space = await this.lockSpace(manager, id);
      if (space) await this.expire(manager, space, new Date());
    });
  }

  async expireDue() {
    const due = await this.db.getRepository(Reservation).find({
      where: { status: In(live), endTime: LessThanOrEqual(new Date()) },
      order: { endTime: 'ASC' },
      take: 100,
    });
    for (const reservation of due)
      await this.expireSpace(reservation.parkingSpaceId);
  }
}
