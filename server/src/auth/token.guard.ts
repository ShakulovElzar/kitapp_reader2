import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';
import { PrismaService } from '../prisma/prisma.service.js';

export type TokenPayload = {
  sub: string;
  type: 'admin' | 'reader';
  role?: string;
};

abstract class TokenGuard implements CanActivate {
  protected abstract readonly type: TokenPayload['type'];

  constructor(
    protected readonly jwt: JwtService,
    protected readonly prisma: PrismaService,
  ) {}

  /**
   * Loads the account on every request: null if it no longer exists or may not
   * sign in. The returned role (admins) replaces whatever the token says.
   */
  protected abstract loadAccount(id: string): Promise<{ role?: string } | null>;

  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<Request & { auth?: TokenPayload }>();
    const value = request.headers.authorization;
    const token = value?.startsWith('Bearer ') ? value.slice(7) : null;
    if (!token) throw new UnauthorizedException('Авторизация керек');

    let payload: TokenPayload;
    try {
      payload = await this.jwt.verifyAsync<TokenPayload>(token);
      if (payload.type !== this.type) throw new Error('Wrong token type');
    } catch {
      throw new UnauthorizedException('Токен жараксыз');
    }
    const account = await this.loadAccount(payload.sub);
    if (!account) {
      throw new UnauthorizedException('Аккаунт бөгөттөлгөн же өчүрүлгөн');
    }
    request.auth = { ...payload, role: account.role };
    return true;
  }
}

@Injectable()
export class AdminGuard extends TokenGuard {
  protected readonly type = 'admin' as const;

  constructor(jwt: JwtService, prisma: PrismaService) {
    super(jwt, prisma);
  }

  protected loadAccount(id: string) {
    return this.prisma.admin.findUnique({ where: { id }, select: { role: true } });
  }
}

@Injectable()
export class ReaderGuard extends TokenGuard {
  protected readonly type = 'reader' as const;

  constructor(jwt: JwtService, prisma: PrismaService) {
    super(jwt, prisma);
  }

  protected async loadAccount(id: string) {
    const reader = await this.prisma.reader.findUnique({
      where: { id },
      select: { isBlocked: true, deletedAt: true },
    });
    return reader && !reader.isBlocked && !reader.deletedAt ? {} : null;
  }
}

/** Use after AdminGuard: revenue, readers, blocking and the audit log are SUPERADMIN only. */
@Injectable()
export class SuperAdminGuard implements CanActivate {
  canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<Request & { auth?: TokenPayload }>();
    if (request.auth?.type === 'admin' && request.auth.role === 'SUPERADMIN') return true;
    throw new ForbiddenException('Бул бөлүм башкы админ үчүн гана');
  }
}
