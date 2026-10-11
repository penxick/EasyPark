import { Transform } from 'class-transformer';
import {
  IsBoolean,
  IsNumber,
  IsString,
  Length,
  Min,
  Validate,
  ValidateIf,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';

@ValidatorConstraint({ name: 'parkingPolygon', async: false })
class ParkingPolygon implements ValidatorConstraintInterface {
  validate(value: unknown): boolean {
    return (
      value === null ||
      (Array.isArray(value) &&
        value.length >= 3 &&
        value.length <= 1000 &&
        value.every(
          (point) =>
            Array.isArray(point) &&
            point.length === 2 &&
            point.every(
              (coordinate) =>
                typeof coordinate === 'number' && Number.isFinite(coordinate),
            ),
        ))
    );
  }
  defaultMessage(): string {
    return 'Polygon должен быть null или массивом из 3–1000 пар конечных чисел.';
  }
}

export class CreateParkingSpaceDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(1, 20)
  code!: string;

  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(0)
  x!: number;

  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(0)
  y!: number;

  @Validate(ParkingPolygon)
  polygon!: [number, number][] | null;
}

export class UpdateParkingSpaceDto extends CreateParkingSpaceDto {
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare code: string;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare x: number;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare y: number;
  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  declare polygon: [number, number][] | null;

  @ValidateIf((_: unknown, value: unknown) => value !== undefined)
  @IsBoolean()
  available?: boolean;
}
