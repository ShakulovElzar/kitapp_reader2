import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AdminController } from './admin/admin.controller.js';
import { AdminService } from './admin/admin.service.js';
import { AuthController } from './auth/auth.controller.js';
import { AuthService } from './auth/auth.service.js';
import { AdminGuard, ReaderGuard } from './auth/token.guard.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { PublicController } from './public/public.controller.js';
import { PublicService } from './public/public.service.js';
import { StorageService } from './storage/storage.service.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    JwtModule.register({
      global: true,
      secret: process.env.JWT_SECRET ?? 'local-kitapp-secret',
      signOptions: { expiresIn: '7d' },
    }),
    PrismaModule,
  ],
  controllers: [AuthController, AdminController, PublicController],
  providers: [
    AuthService,
    AdminService,
    PublicService,
    StorageService,
    AdminGuard,
    ReaderGuard,
  ],
})
export class AppModule {}
