import { Transform } from 'class-transformer';
import {
  IsNumber,
  IsString,
  Length,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';

const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class CreateParkingDto {
  @Transform(trim)
  @IsString()
  @Length(1, 200)
  name!: string;

  @Transform(trim)
  @IsString()
  @Length(1, 10000)
  description!: string;

  @Transform(trim)
  @IsString()
  @Length(1, 500)
  address!: string;

  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  latitude!: number;

  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  longitude!: number;

  @IsNumber({ allowNaN: false, allowInfinity: false, maxDecimalPlaces: 2 })
  @Min(0)
  @Max(99999999.99)
  pricePerHour!: number;

  @Transform(trim)
  @IsString()
  @Length(1, 200)
  workingHours!: string;
}

// Skip only omitted fields. Explicit null still fails inherited validation.
export class UpdateParkingDto extends CreateParkingDto {
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare name: string;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare description: string;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare address: string;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare latitude: number;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare longitude: number;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare pricePerHour: number;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare workingHours: string;
}
