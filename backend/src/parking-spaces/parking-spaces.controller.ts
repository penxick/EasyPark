import {
  BadRequestException,
  Controller,
  Get,
  Param,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ParkingSpacesService } from './parking-spaces.service';

@Controller('parkings/:parkingId/spaces')
@UseGuards(JwtAuthGuard)
export class ParkingSpacesController {
  constructor(private readonly spaces: ParkingSpacesService) {}
  @Get()
  findAll(@Param('parkingId') id: string) {
    if (!/^[1-9]\d*$/.test(id) || Number(id) > 2147483647)
      throw new BadRequestException('Некорректный идентификатор парковки.');
    return this.spaces.findByParking(Number(id));
  }
}
