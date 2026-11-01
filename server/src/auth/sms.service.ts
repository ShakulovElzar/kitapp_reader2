import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';

/**
 * Sends OTP codes by SMS.
 *
 * SMS_PROVIDER=log prints codes to the server log (local development only).
 * A Kyrgyz SMS gateway still has to be chosen; until then any other mode
 * refuses to send rather than silently dropping the code.
 */
@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);
  private readonly provider = process.env.SMS_PROVIDER
    ?? (process.env.OTP_MODE === 'local' ? 'log' : 'none');

  async sendCode(phone: string, code: string) {
    if (this.provider === 'log') {
      this.logger.log(`OTP for ${phone}: ${code}`);
      return;
    }
    throw new ServiceUnavailableException('SMS кызматы азырынча жөндөлгөн эмес');
  }
}
