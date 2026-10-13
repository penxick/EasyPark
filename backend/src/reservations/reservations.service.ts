import {
  ConflictException,
  BadRequestException,
  ServiceUnavailableException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  DataSource,
  EntityManager,
  In,
  IsNull,
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
import { ConfigService } from '@nestjs/config';
import { CreateParkingSessionDto, DemoParkingEventDto } from './session.dto';
import { hourlyCost } from './money';
import {
  AdminReservationsQueryDto,
  pageResult,
  ReservationCategory,
} from '../admin/admin-query.dto';
import {
  adminReservation,
  adminReservationQuery,
  AdminReservationRow,
  adminReservationStatus,
} from './admin-reservation.projection';

const live = [ReservationStatus.ACTIVE, ReservationStatus.PENDING];

@Injectable()
export class ReservationsService {
  constructor(
    private readonly db: DataSource,
    private readonly config: ConfigService,
  ) {}

  private sessionView(reservation: Reservation) {
    const now = new Date();
    const seconds = reservation.actualStartTime
      ? Math.max(
          0,
          Math.floor(
            ((reservation.actualEndTime ?? now).getTime() -
              reservation.actualStartTime.getTime()) /
              1000,
          ),
        )
      : 0;
    return {
      ...reservation,
      totalPrice: Number(reservation.totalPrice),
      serverNow: now,
      elapsedSeconds: seconds,
      currentPrice: reservation.hourlyRateSnapshot
        ? hourlyCost(reservation.hourlyRateSnapshot, seconds)
        : null,
    };
  }

  async createSession(userId: number, dto: CreateParkingSessionDto) {
    if (dto.mode === 'METERED' && dto.plannedMinutes !== undefined)
      throw new BadRequestException(
        'Для режима по счётчику плановое время не задаётся.',
      );
    return this.db.transaction(async (manager) => {
      const space = await this.lockSpace(manager, dto.parkingSpaceId);
      if (!space) throw new NotFoundException('Место не найдено.');
      const now = new Date();
      await this.expireLockedSpace(manager, space, now);
      if (
        space.status !== ParkingSpaceStatus.FREE ||
        space.physicalOccupied ||
        (await manager.existsBy(Reservation, {
          parkingSpaceId: space.id,
          status: In(live),
        }))
      )
        throw new ConflictException('Место уже недоступно для бронирования.');
      // Fetch PostgreSQL numeric as text, bypassing the legacy number transformer.
      const [parking]: { rate: string }[] = await manager.query(
        'SELECT "pricePerHour"::text AS rate FROM parkings WHERE id=$1',
        [space.parkingId],
      );
      const preliminary =
        dto.mode === 'PLANNED'
          ? hourlyCost(parking.rate, dto.plannedMinutes! * 60)
          : null;
      const reservation = await manager.save(
        Reservation,
        manager.create(Reservation, {
          userId,
          parkingSpaceId: space.id,
          mode: dto.mode,
          paymentMethod: dto.paymentMethod,
          paymentStatus:
            dto.mode === 'PLANNED' ? 'DEMO_CONFIRMED' : 'DEMO_PENDING',
          sessionState: 'WAITING_ARRIVAL',
          plannedMinutes: dto.plannedMinutes ?? null,
          hourlyRateSnapshot: parking.rate,
          preliminaryPrice: preliminary,
          totalPrice: preliminary ?? '0.00',
          startTime: now,
          endTime: new Date(
            now.getTime() + (dto.plannedMinutes ?? 1440) * 60000,
          ),
          status: ReservationStatus.PENDING,
        }),
      );
      space.status = ParkingSpaceStatus.RESERVED;
      await manager.save(space);
      return this.sessionView(reservation);
    });
  }

  async finishSession(userId: number, id: number) {
    const found = await this.db.manager.findOneBy(Reservation, { id, userId });
    if (!found) throw new NotFoundException('Бронирование не найдено.');
    return this.db.transaction(async (manager) => {
      await this.lockSpace(manager, found.parkingSpaceId);
      const r = await manager.findOneByOrFail(Reservation, { id, userId });
      if (
        r.sessionState === 'FINISHED' ||
        r.sessionState === 'WAITING_DEPARTURE'
      )
        return this.sessionView(r);
      if (r.sessionState !== 'PARKED')
        throw new ConflictException(
          'Автомобиль ещё не прибыл или сессия завершена.',
        );
      r.sessionState = 'WAITING_DEPARTURE';
      await manager.save(r);
      return this.sessionView(r);
    });
  }

  async demoEvent(id: number, dto: DemoParkingEventDto) {
    if (this.config.get<string>('DEMO_PARKING_EVENTS_ENABLED') !== 'true')
      throw new ServiceUnavailableException(
        'Демонстрационные события отключены.',
      );
    const found = await this.db.manager.findOneBy(Reservation, { id });
    if (!found) throw new NotFoundException('Бронирование не найдено.');
    return this.db.transaction(async (manager) => {
      const space = await this.lockSpace(manager, found.parkingSpaceId);
      if (!space) throw new NotFoundException('Место не найдено.');
      const r = await manager.findOneByOrFail(Reservation, { id });
      const now = new Date();
      if (dto.event === 'ARRIVAL') {
        if (
          r.sessionState === 'PARKED' ||
          r.sessionState === 'WAITING_DEPARTURE'
        )
          return this.sessionView(r);
        if (r.sessionState !== 'WAITING_ARRIVAL')
          throw new ConflictException('Недопустимое подтверждение прибытия.');
        r.actualStartTime = now;
        r.sessionState = 'PARKED';
        r.status = ReservationStatus.ACTIVE;
        space.physicalOccupied = true;
      } else {
        if (r.sessionState === 'FINISHED') return this.sessionView(r);
        if (
          !r.actualStartTime ||
          !['PARKED', 'WAITING_DEPARTURE'].includes(r.sessionState ?? '')
        )
          throw new ConflictException('Недопустимое подтверждение выезда.');
        r.actualEndTime = now;
        r.actualSeconds = Math.max(
          0,
          Math.floor((now.getTime() - r.actualStartTime.getTime()) / 1000),
        );
        r.finalPrice = hourlyCost(r.hourlyRateSnapshot!, r.actualSeconds);
        r.totalPrice = r.finalPrice;
        r.sessionState = 'FINISHED';
        r.status = ReservationStatus.COMPLETED;
        r.paymentStatus = 'DEMO_CONFIRMED';
        // This ADMIN-only demo event explicitly confirms physical departure.
        space.physicalOccupied = false;
      }
      await manager.save(r);
      await manager.save(space);
      if (dto.event === 'DEPARTURE') await this.release(manager, space);
      return this.sessionView(r);
    });
  }

  async adminList(query: AdminReservationsQueryDto, userId?: number) {
    return this.db.transaction('REPEATABLE READ', async (manager) => {
      const builder = adminReservationQuery(manager, new Date());
      if (userId !== undefined)
        builder.andWhere('reservation.userId = :userId', { userId });
      const categories = {
        [ReservationCategory.ACTIVE]: [
          ReservationStatus.ACTIVE,
          ReservationStatus.PENDING,
        ],
        [ReservationCategory.COMPLETED]: [
          ReservationStatus.COMPLETED,
          ReservationStatus.EXPIRED,
        ],
        [ReservationCategory.CANCELLED]: [ReservationStatus.CANCELLED],
      };
      if (query.category !== ReservationCategory.ALL) {
        builder.andWhere(`(${adminReservationStatus}) IN (:...statuses)`, {
          statuses: categories[query.category],
        });
      }
      const total = await builder.getCount();
      const rows = await builder
        .orderBy('reservation.createdAt', 'DESC')
        .addOrderBy('reservation.id', 'DESC')
        .offset((query.page - 1) * query.pageSize)
        .limit(query.pageSize)
        .getRawMany<AdminReservationRow>();
      return pageResult(rows.map(adminReservation), total, query);
    });
  }

  async adminDetails(id: number) {
    const row = await adminReservationQuery(this.db.manager, new Date())
      .where('reservation.id = :id', { id })
      .getRawOne<AdminReservationRow>();
    if (!row) throw new NotFoundException('Бронирование не найдено.');
    return adminReservation(row);
  }

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

  // Caller must hold the space's pessimistic write lock in this transaction.
  async expireLockedSpace(
    manager: EntityManager,
    space: ParkingSpace,
    now: Date,
  ) {
    const ended = await manager.findBy(Reservation, {
      mode: IsNull(),
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
        await this.expireLockedSpace(manager, space, now);
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
        // PostgreSQL numeric arrives as a decimal string. All arithmetic is integer.
        const [rubles, fraction = ''] = parking.pricePer30Min.split('.');
        const cents =
          (BigInt(rubles) * 100n + BigInt(fraction.padEnd(2, '0'))) *
          BigInt(dto.durationMinutes / 30);
        const totalPrice = `${cents / 100n}.${(cents % 100n).toString().padStart(2, '0')}`;
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
        return { ...reservation, totalPrice: Number(reservation.totalPrice) };
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
      mode: IsNull(),
      userId,
      status: In(live),
      endTime: LessThanOrEqual(new Date()),
    });
    for (const reservation of active)
      await this.expireSpace(reservation.parkingSpaceId);
    const items = await this.db
      .getRepository(Reservation)
      .find({ where: { userId }, order: { createdAt: 'DESC', id: 'DESC' } });
    return items.map((item) => this.sessionView(item));
  }

  async cancel(userId: number, id: number) {
    const found = await this.db
      .getRepository(Reservation)
      .findOneBy({ id, userId });
    if (!found) throw new NotFoundException('Бронирование не найдено.');
    const result = await this.db.transaction(async (manager) => {
      const space = await this.lockSpace(manager, found.parkingSpaceId);
      if (!space) throw new NotFoundException('Место не найдено.');
      await this.expireLockedSpace(manager, space, new Date());
      const reservation = await manager.findOneByOrFail(Reservation, {
        id,
        userId,
      });
      if (reservation.status === ReservationStatus.CANCELLED)
        return reservation;
      if (reservation.mode && reservation.sessionState !== 'WAITING_ARRIVAL')
        throw new ConflictException(
          'После прибытия запросите завершение парковки.',
        );
      if (!live.includes(reservation.status)) return null;
      reservation.status = ReservationStatus.CANCELLED;
      if (reservation.mode) reservation.sessionState = 'CANCELLED';
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
      if (space) await this.expireLockedSpace(manager, space, new Date());
    });
  }

  async expireDue() {
    const due = await this.db.getRepository(Reservation).find({
      where: {
        mode: IsNull(),
        status: In(live),
        endTime: LessThanOrEqual(new Date()),
      },
      order: { endTime: 'ASC' },
      take: 100,
    });
    for (const reservation of due)
      await this.expireSpace(reservation.parkingSpaceId);
  }
}
