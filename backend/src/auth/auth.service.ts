import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import { User, publicUser } from '../users/user.entity';
import { LoginDto, RegisterDto } from './auth.dto';
import { DUMMY_PASSWORD_HASH, PasswordService } from './password.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersService,
    private readonly passwords: PasswordService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    const hash = await this.passwords.hash(dto.password);
    const user = await this.users.create(dto.name, dto.email, hash);
    return this.session(user);
  }

  async login(dto: LoginDto) {
    const user = await this.users.findForLogin(dto.email);
    const valid = await this.passwords.verify(
      dto.password,
      user?.passwordHash ?? DUMMY_PASSWORD_HASH,
    );
    if (!user || !valid)
      throw new UnauthorizedException('Неверный email или пароль.');
    return this.session(user);
  }

  private async session(user: User) {
    return {
      accessToken: await this.jwt.signAsync({ sub: String(user.id) }),
      user: publicUser(user),
    };
  }
}
