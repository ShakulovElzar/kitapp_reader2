import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { randomInt } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import { AdminLoginDto, RequestOtpDto, VerifyOtpDto } from './auth.dto.js';
import { SmsService } from './sms.service.js';

const MAX_ATTEMPTS_PER_CODE = 5;
const MAX_CODES_PER_PHONE_PER_HOUR = 5;
const IP_WINDOW_MS = 10 * 60 * 1000;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly sms: SmsService,
  ) {}

  /** Recent OTP request times per client IP (in memory; fine for one server). */
  private readonly ipRequests = new Map<string, number[]>();

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

  async requestOtp(dto: RequestOtpDto, ip = 'unknown') {
    const phone = this.normalizePhone(dto.phone);
    this.limitIp(ip);
    const recent = await this.prisma.otpCode.findFirst({
      where: { phone, createdAt: { gt: new Date(Date.now() - 60 * 1000) } },
      orderBy: { createdAt: 'desc' },
    });
    if (recent) throw new BadRequestException('Кодду кайра 60 секунддан кийин сураңыз');
    const lastHour = await this.prisma.otpCode.count({
      where: { phone, createdAt: { gt: new Date(Date.now() - 60 * 60 * 1000) } },
    });
    if (lastHour >= MAX_CODES_PER_PHONE_PER_HOUR) {
      throw new HttpException('Өтө көп сурам. Бир сааттан кийин кайталаңыз', HttpStatus.TOO_MANY_REQUESTS);
    }
    const local = process.env.OTP_MODE === 'local';
    const code = local ? '111111' : randomInt(100000, 1000000).toString();
    await this.sms.sendCode(phone, code);
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
      ...(local ? { developmentCode: code } : {}),
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const phone = this.normalizePhone(dto.phone);
    const otp = await this.prisma.otpCode.findFirst({
      where: { phone, usedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) throw new UnauthorizedException('Код туура эмес же мөөнөтү бүттү');
    if (otp.attempts >= MAX_ATTEMPTS_PER_CODE) {
      throw new UnauthorizedException('Өтө көп туура эмес аракет. Жаңы код сураңыз');
    }
    if (!(await bcrypt.compare(dto.code, otp.codeHash))) {
      const attempts = otp.attempts + 1;
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        // Burn the code once the attempt limit is reached.
        data: { attempts, ...(attempts >= MAX_ATTEMPTS_PER_CODE ? { usedAt: new Date() } : {}) },
      });
      throw new UnauthorizedException(
        attempts >= MAX_ATTEMPTS_PER_CODE
          ? 'Өтө көп туура эмес аракет. Жаңы код сураңыз'
          : 'Код туура эмес же мөөнөтү бүттү',
      );
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

  private limitIp(ip: string) {
    const now = Date.now();
    const recent = (this.ipRequests.get(ip) ?? []).filter((time) => now - time < IP_WINDOW_MS);
    // Read at call time so the value from .env (loaded after imports) applies.
    if (recent.length >= Number(process.env.OTP_IP_LIMIT ?? 10)) {
      throw new HttpException('Өтө көп сурам. Бир аздан кийин кайталаңыз', HttpStatus.TOO_MANY_REQUESTS);
    }
    recent.push(now);
    this.ipRequests.set(ip, recent);
  }
}
