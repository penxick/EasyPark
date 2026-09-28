import { Transform } from 'class-transformer';
import { IsEmail, IsString, Length, Matches, MaxLength } from 'class-validator';

export class LoginDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail({}, { message: 'Укажите корректный email.' })
  @MaxLength(254)
  email!: string;

  @IsString()
  @Length(1, 128)
  password!: string;
}

export class RegisterDto extends LoginDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @Length(1, 100, { message: 'Имя должно содержать от 1 до 100 символов.' })
  name!: string;

  @IsString()
  @Length(8, 128, { message: 'Пароль должен содержать от 8 до 128 символов.' })
  @Matches(/\S/u, { message: 'Пароль не может состоять только из пробелов.' })
  declare password: string;
}
