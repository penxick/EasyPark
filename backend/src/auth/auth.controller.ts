import {
  Body,
  Controller,
  Header,
  HttpCode,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import {
  LoginDto,
  RegisterDto,
  PasswordResetRequestDto,
  PasswordResetConfirmDto,
} from './auth.dto';
import { PasswordResetService } from './password-reset.service';

@Controller('auth')
@UseGuards(ThrottlerGuard)
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly resets: PasswordResetService,
  ) {}
  @Post('password-reset/request')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  requestReset(@Body() dto: PasswordResetRequestDto) {
    return this.resets.request(dto.email);
  }
  @Post('password-reset/confirm')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  confirmReset(@Body() dto: PasswordResetConfirmDto) {
    return this.resets.confirm(dto.email, dto.code, dto.password);
  }

  @Post('register')
  @Header('Cache-Control', 'no-store')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }
}
