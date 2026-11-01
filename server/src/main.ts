import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import type { NextFunction, Request, Response } from 'express';
import { AppModule } from './app.module.js';
import { PrismaExceptionFilter } from './prisma/prisma-exception.filter.js';
import { StorageService } from './storage/storage.service.js';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.setGlobalPrefix('api');
  app.enableCors({
    origin: process.env.ADMIN_ORIGIN?.split(',') ?? [
      'http://localhost:5173',
      'http://127.0.0.1:5173',
      'http://localhost:8083',
      'http://127.0.0.1:8083',
    ],
    credentials: true,
  });
  const storage = app.get(StorageService);
  // Covers are public; book files are only served through signed, expiring links.
  app.useStaticAssets(storage.coversPath, { prefix: '/files/covers/' });
  app.use('/files/s', (req: Request, res: Response, next: NextFunction) => {
    const match = /^\/([^/]+)\/books\/([^/]+)\/(.+)$/.exec(req.path);
    const file = match && storage.resolveSignedPath(match[1], match[2], match[3]);
    if (!file) {
      res.status(403).json({ statusCode: 403, message: 'Шилтеме жараксыз же мөөнөтү бүттү' });
      return;
    }
    res.setHeader('Cache-Control', 'private, max-age=3600');
    const textTypes: Record<string, string> = {
      xhtml: 'application/xhtml+xml', html: 'text/html', htm: 'text/html',
      css: 'text/css', json: 'application/json',
    };
    const type = textTypes[file.split('.').pop()?.toLowerCase() ?? ''];
    if (type) res.setHeader('Content-Type', `${type}; charset=utf-8`);
    res.sendFile(file, (error) => {
      if (error && !res.headersSent) next();
    });
  });
  app.useGlobalFilters(new PrismaExceptionFilter());
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true }),
  );

  await app.listen(
    Number(process.env.PORT ?? 3000),
    process.env.HOST ?? '127.0.0.1',
  );
}

void bootstrap();
