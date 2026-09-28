import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

@Controller('health')
export class HealthController {
  constructor(@InjectDataSource() private readonly database: DataSource) {}

  @Get()
  async getHealth(): Promise<{ status: string; service: string }> {
    try {
      await this.database.query('SELECT 1');
      return { status: 'ok', service: 'easypark-backend' };
    } catch {
      throw new ServiceUnavailableException({
        status: 'error',
        service: 'easypark-backend',
        database: 'unavailable',
      });
    }
  }
}
