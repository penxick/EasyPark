import {
  BadRequestException,
  Controller,
  Get,
  Param,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ParkingService } from './parking.service';

@Controller('parkings')
@UseGuards(JwtAuthGuard)
export class ParkingController {
  constructor(private readonly parkings: ParkingService) {}
  @Get()
  findAll() {
    return this.parkings.findAll();
  }
  @Get(':id')
  findOne(@Param('id') id: string) {
    if (!/^[1-9]\d*$/.test(id) || Number(id) > 2147483647) {
      throw new BadRequestException('Некорректный идентификатор парковки.');
    }
    return this.parkings.findOne(Number(id));
  }
}
