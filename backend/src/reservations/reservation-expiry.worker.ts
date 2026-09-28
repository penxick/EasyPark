import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnModuleDestroy,
} from '@nestjs/common';
import { ReservationsService } from './reservations.service';

@Injectable()
export class ReservationExpiryWorker
  implements OnApplicationBootstrap, OnModuleDestroy
{
  private timer?: ReturnType<typeof setInterval>;
  private running?: Promise<void>;
  private readonly logger = new Logger(ReservationExpiryWorker.name);
  constructor(private readonly reservations: ReservationsService) {}
  onApplicationBootstrap() {
    // Delay the first pass: the same application context is used by migrations.
    this.timer = setInterval(() => {
      if (this.running) return;
      this.running = this.reservations
        .expireDue()
        .catch(() => {
          this.logger.error(
            'Не удалось завершить истёкшие бронирования; проверка будет повторена.',
          );
        })
        .finally(() => {
          this.running = undefined;
        });
    }, 30000);
    this.timer.unref();
  }
  async onModuleDestroy() {
    clearInterval(this.timer);
    await this.running;
  }
}
