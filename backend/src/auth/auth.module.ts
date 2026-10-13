import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerModule } from '@nestjs/throttler';
import { UsersModule } from '../users/users.module';
import { UsersController } from '../users/users.controller';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { PasswordService } from './password.service';
import { RoleGuard } from './role.guard';
import { AdminBootstrapService } from './admin-bootstrap.service';
import { PasswordResetService } from './password-reset.service';

export const JWT_ISSUER = 'easypark-backend';
export const JWT_AUDIENCE = 'easypark-mobile';

@Module({
  imports: [
    UsersModule,
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 20 }]),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: {
          algorithm: 'HS256',
          expiresIn: config.getOrThrow<number>('JWT_TTL_SECONDS'),
          issuer: JWT_ISSUER,
          audience: JWT_AUDIENCE,
        },
        verifyOptions: {
          algorithms: ['HS256'],
          issuer: JWT_ISSUER,
          audience: JWT_AUDIENCE,
        },
      }),
    }),
  ],
  controllers: [AuthController, UsersController],
  providers: [
    PasswordResetService,
    AuthService,
    PasswordService,
    JwtAuthGuard,
    RoleGuard,
    AdminBootstrapService,
  ],
  exports: [
    JwtAuthGuard,
    RoleGuard,
    JwtModule,
    UsersModule,
    AdminBootstrapService,
  ],
})
export class AuthModule {}
