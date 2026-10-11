import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, Repository } from 'typeorm';
import { publicUser, User, UserRole } from './user.entity';
import { AdminPageDto, pageResult } from '../admin/admin-query.dto';
import { Reservation } from '../reservations/reservation.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {}

  async adminList(query: AdminPageDto) {
    return this.users.manager.transaction(
      'REPEATABLE READ',
      async (manager) => {
        const [users, total] = await manager.getRepository(User).findAndCount({
          order: { createdAt: 'DESC', id: 'DESC' },
          skip: (query.page - 1) * query.pageSize,
          take: query.pageSize,
        });
        return pageResult(users.map(publicUser), total, query);
      },
    );
  }

  async adminDetails(id: number) {
    const { entities, raw } = await this.users
      .createQueryBuilder('user')
      .addSelect(
        (q) =>
          q
            .select('COUNT(*)::int')
            .from(Reservation, 'reservation')
            .where('reservation.userId = user.id'),
        'reservationCount',
      )
      .addSelect(
        (q) =>
          q
            .select('COUNT(*)::int')
            .from(Reservation, 'reservation')
            .where('reservation.userId = user.id')
            .andWhere("reservation.status IN ('ACTIVE', 'PENDING')")
            .andWhere('reservation.endTime > CURRENT_TIMESTAMP'),
        'activeReservationCount',
      )
      .where('user.id = :id', { id })
      .getRawAndEntities<{
        reservationCount: number;
        activeReservationCount: number;
      }>();
    if (!entities[0]) throw new NotFoundException('Пользователь не найден.');
    return {
      ...publicUser(entities[0]),
      reservationCount: raw[0].reservationCount,
      activeReservationCount: raw[0].activeReservationCount,
    };
  }

  findById(id: number): Promise<User | null> {
    return this.users.findOneBy({ id });
  }

  findForLogin(identifier: string): Promise<User | null> {
    return this.users
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.email = :identifier OR user.login = :identifier', {
        identifier,
      })
      .getOne();
  }

  async create(
    name: string,
    email: string,
    passwordHash: string,
  ): Promise<User> {
    if (email.toLowerCase().endsWith('@easypark.invalid')) {
      throw new ConflictException('Этот адрес зарезервирован системой.');
    }
    try {
      // Never accept the role from a public registration request.
      return await this.users.save(
        this.users.create({ name, email, passwordHash, role: UserRole.USER }),
      );
    } catch (error) {
      if (
        error instanceof QueryFailedError &&
        (error.driverError as { code?: string; constraint?: string }).code ===
          '23505' &&
        (error.driverError as { constraint?: string }).constraint ===
          'UQ_users_email'
      ) {
        throw new ConflictException(
          'Пользователь с таким email уже существует.',
        );
      }
      throw error;
    }
  }
}
