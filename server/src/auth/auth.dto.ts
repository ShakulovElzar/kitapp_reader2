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
  // Spaces, dashes and brackets are allowed; AuthService normalizes the number.
  @Matches(/^[\s()-]*(?:\+?996|0)(?:[\s()-]*\d){9}[\s()-]*$/)
  phone!: string;
}

export class VerifyOtpDto extends RequestOtpDto {
  @Matches(/^\d{6}$/)
  code!: string;
}
