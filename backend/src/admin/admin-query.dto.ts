import { Transform } from 'class-transformer';
import { IsEnum, IsInt, Max, Min } from 'class-validator';

const integerQuery = ({ value }: { value: unknown }) =>
  typeof value === 'string' && /^[1-9]\d*$/.test(value) ? Number(value) : value;

export class AdminPageDto {
  @Transform(integerQuery)
  @IsInt()
  @Min(1)
  @Max(1000000)
  page = 1;

  @Transform(integerQuery)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 20;
}

export enum ReservationCategory {
  ALL = 'all',
  ACTIVE = 'active',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

export class AdminReservationsQueryDto extends AdminPageDto {
  @IsEnum(ReservationCategory)
  category = ReservationCategory.ALL;
}

export function pageResult<T>(items: T[], total: number, query: AdminPageDto) {
  return {
    items,
    total,
    page: query.page,
    pageSize: query.pageSize,
    totalPages: Math.ceil(total / query.pageSize),
  };
}
