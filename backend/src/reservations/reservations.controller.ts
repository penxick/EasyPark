import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Header,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { AuthenticatedRequest } from '../auth/jwt-auth.guard';
import { CreateReservationDto } from './reservation.dto';
import { ReservationsService } from './reservations.service';
import { CreateParkingSessionDto, DemoParkingEventDto } from './session.dto';
import { RoleGuard } from '../auth/role.guard';

@Controller('reservations')
@UseGuards(JwtAuthGuard)
export class ReservationsController {
  constructor(private readonly reservations: ReservationsService) {}
  @Post('sessions')
  @Header('Cache-Control', 'no-store')
  session(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateParkingSessionDto,
  ) {
    return this.reservations.createSession(request.user.id, dto);
  }
  @Patch(':id/finish')
  @Header('Cache-Control', 'no-store')
  finish(
    @Req() request: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.reservations.finishSession(request.user.id, id);
  }
  @Post(':id/demo-event')
  @UseGuards(RoleGuard)
  @Header('Cache-Control', 'no-store')
  demoEvent(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: DemoParkingEventDto,
  ) {
    return this.reservations.demoEvent(id, dto);
  }
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
