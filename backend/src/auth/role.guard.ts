import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { AuthenticatedRequest } from './jwt-auth.guard';
import { UserRole } from '../users/user.entity';

// Always run after JwtAuthGuard: the role comes from the current database row.
@Injectable()
export class RoleGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    if (request.user?.role !== UserRole.ADMIN) {
      throw new ForbiddenException('Нет доступа.');
    }
    return true;
  }
}
