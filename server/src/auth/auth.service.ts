import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service.js';
import { AdminLoginDto, RequestOtpDto, VerifyOtpDto } from './auth.dto.js';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async adminLogin(dto: AdminLoginDto) {
    const admin = await this.prisma.admin.findUnique({
      where: { email: dto.email.toLowerCase() },
    });
    if (!admin || !(await bcrypt.compare(dto.password, admin.passwordHash))) {
      throw new UnauthorizedException('Email же сырсөз туура эмес');
    }

    return {
      token: await this.jwt.signAsync({
        sub: admin.id,
        role: admin.role,
        type: 'admin',
      }),
      admin: { id: admin.id, name: admin.name, email: admin.email, role: admin.role },
    };
  }

  async requestOtp(dto: RequestOtpDto) {
    const phone = this.normalizePhone(dto.phone);
    const recent = await this.prisma.otpCode.findFirst({
      where: { phone, createdAt: { gt: new Date(Date.now() - 60 * 1000) } },
      orderBy: { createdAt: 'desc' },
    });
    if (recent) throw new BadRequestException('Кодду кайра 60 секунддан кийин сураңыз');
    const code = process.env.OTP_MODE === 'local' ? '111111' : this.randomCode();
    const codeHash = await bcrypt.hash(code, 10);
    const reader = await this.prisma.reader.findUnique({ where: { phone } });

    await this.prisma.otpCode.create({
      data: {
        phone,
        readerId: reader?.id,
        codeHash,
        expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      },
    });

    return {
      phone,
      expiresInSeconds: 300,
      ...(process.env.OTP_MODE === 'local' ? { developmentCode: code } : {}),
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const phone = this.normalizePhone(dto.phone);
    const otp = await this.prisma.otpCode.findFirst({
      where: { phone, usedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp || !(await bcrypt.compare(dto.code, otp.codeHash))) {
      throw new UnauthorizedException('Код туура эмес же мөөнөтү бүттү');
    }

    const reader = await this.prisma.reader.upsert({
      where: { phone },
      create: { phone },
      update: {},
    });
    if (reader.isBlocked) {
      throw new UnauthorizedException('Колдонуучу бөгөттөлгөн');
    }
    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { usedAt: new Date(), readerId: reader.id },
    });

    return {
      token: await this.jwt.signAsync({ sub: reader.id, type: 'reader' }),
      reader: { id: reader.id, phone: reader.phone, name: reader.name },
    };
  }

  private normalizePhone(value: string) {
    const compact = value.replace(/[\s()-]/g, '');
    const phone = compact.startsWith('+996')
      ? compact
      : compact.startsWith('996')
        ? `+${compact}`
        : compact.startsWith('0')
          ? `+996${compact.slice(1)}`
          : compact;
    if (!/^\+996\d{9}$/.test(phone)) {
      throw new BadRequestException('Телефон +996XXXXXXXXX форматында болушу керек');
    }
    return phone;
  }

  private randomCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }
}
