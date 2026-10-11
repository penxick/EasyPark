import { Controller, Get, Header, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RoleGuard } from '../auth/role.guard';
import { AdminPageDto } from './admin-query.dto';
import { AdminAnalyticsService } from './admin-analytics.service';

@Controller('admin/analytics')
@UseGuards(JwtAuthGuard, RoleGuard)
export class AdminAnalyticsController {
  constructor(private readonly analytics: AdminAnalyticsService) {}

  @Get()
  @Header('Cache-Control', 'no-store')
  summary() {
    return this.analytics.summary();
  }

  @Get('parkings')
  @Header('Cache-Control', 'no-store')
  parkings(@Query() query: AdminPageDto) {
    return this.analytics.parkings(query);
  }
}
