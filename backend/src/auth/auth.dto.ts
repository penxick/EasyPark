import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsString,
  Length,
  Matches,
  MaxLength,
  ValidateIf,
} from 'class-validator';

export class LoginDto {
  @ValidateIf((dto: LoginDto) => dto.email !== undefined)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail({}, { message: 'Укажите корректный email.' })
  @MaxLength(254)
  email?: string;

  @ValidateIf((dto: LoginDto) => dto.login !== undefined)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsString()
  @Length(1, 254)
  login?: string;

  @IsString()
  @Length(1, 128)
  password!: string;
}

export class RegisterDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail({}, { message: 'Укажите корректный email.' })
  @MaxLength(254)
  email!: string;
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(1, 100, { message: 'Имя должно содержать от 1 до 100 символов.' })
  name!: string;

  @IsString()
  @Length(8, 128, { message: 'Пароль должен содержать от 8 до 128 символов.' })
  @Matches(/\S/u, { message: 'Пароль не может состоять только из пробелов.' })
  password!: string;
}
