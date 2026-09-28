import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Header,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { CreateReservationDto } from './reservation.dto';
import { ReservationsService } from './reservations.service';

@Controller('reservations')
@UseGuards(JwtAuthGuard)
export class ReservationsController {
  constructor(private readonly reservations: ReservationsService) {}
  @Post()
  @Header('Cache-Control', 'no-store')
  create(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateReservationDto,
  ) {
    return this.reservations.create(request.user.id, dto);
  }
  @Get('me')
  @Header('Cache-Control', 'no-store')
  mine(@Req() request: AuthenticatedRequest) {
    return this.reservations.mine(request.user.id);
  }
  @Patch(':id/cancel')
  @Header('Cache-Control', 'no-store')
  cancel(@Req() request: AuthenticatedRequest, @Param('id') id: string) {
    if (!/^[1-9]\d*$/.test(id) || Number(id) > 2147483647)
      throw new BadRequestException('Некорректный идентификатор бронирования.');
    return this.reservations.cancel(request.user.id, Number(id));
  }
}
