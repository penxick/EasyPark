import { ConflictException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, Repository } from 'typeorm';
import { User, UserRole } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {}

  findById(id: number): Promise<User | null> {
    return this.users.findOneBy({ id });
  }

  findForLogin(email: string): Promise<User | null> {
    return this.users
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.email = :email', { email })
      .getOne();
  }

  async create(
    name: string,
    email: string,
    passwordHash: string,
  ): Promise<User> {
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
