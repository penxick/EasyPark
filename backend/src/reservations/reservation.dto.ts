import { IsIn, IsInt, Max, Min } from 'class-validator';

export class CreateReservationDto {
  @IsInt() @Min(1) @Max(2147483647) parkingSpaceId!: number;
  @IsInt() @IsIn([30, 60, 120, 180]) durationMinutes!: number;
}
