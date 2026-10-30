import {
  CanActivate,
  ExecutionContext,
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

  /** Checks the account still exists and may sign in; runs on every request. */
  protected abstract isActive(id: string): Promise<boolean>;

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
    if (!(await this.isActive(payload.sub))) {
      throw new UnauthorizedException('Аккаунт бөгөттөлгөн же өчүрүлгөн');
    }
    request.auth = payload;
    return true;
  }
}

@Injectable()
export class AdminGuard extends TokenGuard {
  protected readonly type = 'admin' as const;

  constructor(jwt: JwtService, prisma: PrismaService) {
    super(jwt, prisma);
  }

  protected async isActive(id: string) {
    return Boolean(await this.prisma.admin.findUnique({ where: { id }, select: { id: true } }));
  }
}

@Injectable()
export class ReaderGuard extends TokenGuard {
  protected readonly type = 'reader' as const;

  constructor(jwt: JwtService, prisma: PrismaService) {
    super(jwt, prisma);
  }

  protected async isActive(id: string) {
    const reader = await this.prisma.reader.findUnique({
      where: { id },
      select: { isBlocked: true, deletedAt: true },
    });
    return Boolean(reader && !reader.isBlocked && !reader.deletedAt);
  }
}
