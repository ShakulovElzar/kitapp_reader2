import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';

export type TokenPayload = {
  sub: string;
  type: 'admin' | 'reader';
  role?: string;
};

abstract class TokenGuard implements CanActivate {
  protected abstract readonly type: TokenPayload['type'];

  constructor(protected readonly jwt: JwtService) {}

  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<Request & { auth?: TokenPayload }>();
    const value = request.headers.authorization;
    const token = value?.startsWith('Bearer ') ? value.slice(7) : null;
    if (!token) throw new UnauthorizedException('Авторизация керек');

    try {
      const payload = await this.jwt.verifyAsync<TokenPayload>(token);
      if (payload.type !== this.type) throw new Error('Wrong token type');
      request.auth = payload;
      return true;
    } catch {
      throw new UnauthorizedException('Токен жараксыз');
    }
  }
}

@Injectable()
export class AdminGuard extends TokenGuard {
  protected readonly type = 'admin' as const;

  constructor(jwt: JwtService) {
    super(jwt);
  }
}

@Injectable()
export class ReaderGuard extends TokenGuard {
  protected readonly type = 'reader' as const;

  constructor(jwt: JwtService) {
    super(jwt);
  }
}
