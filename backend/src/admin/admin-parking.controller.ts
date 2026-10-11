import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  HttpCode,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RoleGuard } from '../auth/role.guard';
import { ParkingService } from '../parking/parking.service';
import { CreateParkingDto, UpdateParkingDto } from '../parking/parking.dto';

@Controller('admin/parkings')
@UseGuards(JwtAuthGuard, RoleGuard)
export class AdminParkingController {
  constructor(private readonly parkings: ParkingService) {}

  @Post()
  create(@Body() dto: CreateParkingDto) {
    return this.parkings.create(dto);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateParkingDto) {
    return this.parkings.update(this.id(id), dto);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@Param('id') id: string): Promise<void> {
    await this.parkings.remove(this.id(id));
  }

  private id(value: string): number {
    if (!/^[1-9]\d*$/.test(value) || Number(value) > 2147483647) {
      throw new BadRequestException('Некорректный идентификатор парковки.');
    }
    return Number(value);
  }
}
