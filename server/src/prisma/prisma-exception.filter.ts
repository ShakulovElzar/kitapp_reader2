import { ArgumentsHost, Catch, ExceptionFilter, HttpStatus } from '@nestjs/common';
import type { Response } from 'express';
import { Prisma } from '../generated/prisma/client.js';

/** Turns known database errors into 404/409 instead of a generic 500. */
@Catch(Prisma.PrismaClientKnownRequestError)
export class PrismaExceptionFilter implements ExceptionFilter {
  catch(error: Prisma.PrismaClientKnownRequestError, host: ArgumentsHost) {
    const response = host.switchToHttp().getResponse<Response>();
    const known: Record<string, [number, string]> = {
      P2002: [HttpStatus.CONFLICT, 'Мындай маалымат мурунтан бар'],
      P2025: [HttpStatus.NOT_FOUND, 'Маалымат табылган жок'],
      P2003: [HttpStatus.BAD_REQUEST, 'Байланышкан маалымат табылган жок'],
    };
    const [statusCode, message] = known[error.code] ?? [HttpStatus.INTERNAL_SERVER_ERROR, 'Internal server error'];
    response.status(statusCode).json({ statusCode, message });
  }
}
