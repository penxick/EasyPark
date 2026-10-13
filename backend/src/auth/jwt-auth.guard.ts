import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import { PublicUser, publicUser } from '../users/user.entity';

export interface AuthenticatedRequest {
  headers: { authorization?: string };
  user: PublicUser;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly users: UsersService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const authorization = request.headers.authorization;
    if (typeof authorization !== 'string' || authorization.length > 4096)
      throw new UnauthorizedException();
    const match = /^Bearer ([a-z0-9_-]+\.[a-z0-9_-]+\.[a-z0-9_-]+)$/i.exec(
      authorization,
    );
    if (!match) throw new UnauthorizedException();
    let payload: { sub?: unknown; exp?: unknown; iat?: unknown; ver?: unknown };
    try {
      payload = await this.jwt.verifyAsync(match[1]);
    } catch {
      throw new UnauthorizedException();
    }
    if (
      typeof payload.sub !== 'string' ||
      !/^[1-9]\d*$/.test(payload.sub) ||
      !Number.isSafeInteger(Number(payload.sub)) ||
      Number(payload.sub) > 2147483647 ||
      !Number.isInteger(payload.exp) ||
      !Number.isInteger(payload.iat)
    )
      throw new UnauthorizedException();
    // Read current identity/role from DB; do not trust a role claim in a token.
    const user = await this.users.findById(Number(payload.sub));
    if (!user) throw new UnauthorizedException();
    if ((payload.ver ?? 0) !== (user.tokenVersion ?? 0))
      throw new UnauthorizedException();
    request.user = publicUser(user);
    return true;
  }
}
