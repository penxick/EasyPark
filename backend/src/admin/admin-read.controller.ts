import {
  BadRequestException,
  Controller,
  Get,
  Header,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RoleGuard } from '../auth/role.guard';
import { UsersService } from '../users/users.service';
import { ReservationsService } from '../reservations/reservations.service';
import {
  AdminPageDto,
  AdminReservationsQueryDto,
  ReservationCategory,
} from './admin-query.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RoleGuard)
export class AdminReadController {
  constructor(
    private readonly users: UsersService,
    private readonly reservations: ReservationsService,
  ) {}

  @Get('users')
  @Header('Cache-Control', 'no-store')
  usersList(@Query() query: AdminPageDto) {
    return this.users.adminList(query);
  }

  @Get('users/:id')
  @Header('Cache-Control', 'no-store')
  async userDetails(@Param('id') value: string, @Query() query: AdminPageDto) {
    const id = this.id(value);
    const user = await this.users.adminDetails(id);
    const reservations = await this.reservations.adminList(
      { ...query, category: ReservationCategory.ALL },
      id,
    );
    return { ...user, reservations };
  }

  @Get('reservations')
  @Header('Cache-Control', 'no-store')
  reservationsList(@Query() query: AdminReservationsQueryDto) {
    return this.reservations.adminList(query);
  }

  @Get('reservations/:id')
  @Header('Cache-Control', 'no-store')
  reservationDetails(@Param('id') value: string) {
    return this.reservations.adminDetails(this.id(value));
  }

  private id(value: string): number {
    if (!/^[1-9]\d*$/.test(value) || Number(value) > 2147483647)
      throw new BadRequestException('Некорректный идентификатор.');
    return Number(value);
  }
}
