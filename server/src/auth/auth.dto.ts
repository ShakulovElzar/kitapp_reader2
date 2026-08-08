import { IsEmail, IsString, Matches, MinLength } from 'class-validator';

export class AdminLoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;
}

export class RequestOtpDto {
  @IsString()
  @Matches(/^(?:\+?996|0)\d{9}$/)
  phone!: string;
}

export class VerifyOtpDto extends RequestOtpDto {
  @Matches(/^\d{6}$/)
  code!: string;
}
