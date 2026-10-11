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
import { ParkingSpacesService } from '../parking-spaces/parking-spaces.service';
import {
  CreateParkingSpaceDto,
  UpdateParkingSpaceDto,
} from '../parking-spaces/parking-space.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RoleGuard)
export class AdminSpacesController {
  constructor(private readonly spaces: ParkingSpacesService) {}

  @Post('parkings/:parkingId/spaces')
  create(
    @Param('parkingId') parkingId: string,
    @Body() dto: CreateParkingSpaceDto,
  ) {
    return this.spaces.create(this.id(parkingId), dto);
  }

  @Patch('spaces/:id')
  update(@Param('id') id: string, @Body() dto: UpdateParkingSpaceDto) {
    return this.spaces.update(this.id(id), dto);
  }

  @Delete('spaces/:id')
  @HttpCode(204)
  async remove(@Param('id') id: string): Promise<void> {
    await this.spaces.remove(this.id(id));
  }

  private id(value: string): number {
    if (!/^[1-9]\d*$/.test(value) || Number(value) > 2147483647) {
      throw new BadRequestException('Некорректный идентификатор.');
    }
    return Number(value);
  }
}
