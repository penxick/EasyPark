import { IsIn, IsInt, Max, Min, ValidateIf } from 'class-validator';

export class CreateParkingSessionDto {
  @IsInt() @Min(1) @Max(2147483647) parkingSpaceId!: number;
  @IsIn(['PLANNED', 'METERED']) mode!: 'PLANNED' | 'METERED';
  @IsIn(['CARD', 'SBP']) paymentMethod!: 'CARD' | 'SBP';
  @ValidateIf(
    (dto: CreateParkingSessionDto) =>
      dto.mode === 'PLANNED' || dto.plannedMinutes !== undefined,
  )
  @IsInt()
  @Min(1)
  @Max(1440)
  plannedMinutes?: number;
}

export class DemoParkingEventDto {
  @IsIn(['ARRIVAL', 'DEPARTURE']) event!: 'ARRIVAL' | 'DEPARTURE';
}
