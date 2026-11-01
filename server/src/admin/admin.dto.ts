import { PartialType } from '@nestjs/mapped-types';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
} from 'class-validator';
import { AccessType, BookStatus } from '../generated/prisma/enums.js';

export class CreateAuthorDto {
  @IsString()
  @MinLength(2)
  name!: string;

  @IsOptional()
  @IsString()
  bio?: string;
}

export class UpdateAuthorDto extends PartialType(CreateAuthorDto) {}

export class CreateCategoryDto {
  @IsString()
  @MinLength(2)
  name!: string;

  @IsString()
  @MinLength(2)
  slug!: string;
}

export class UpdateCategoryDto extends PartialType(CreateCategoryDto) {}

export class CreateBookDto {
  @IsString()
  @MinLength(2)
  title!: string;

  @IsString()
  @MinLength(2)
  slug!: string;

  @IsString()
  description!: string;

  @IsString()
  authorId!: string;

  @IsString()
  categoryId!: string;

  @IsNumber()
  @Min(0)
  price!: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  rentalPrice?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  rentalDays?: number;

  @IsInt()
  @Min(1)
  pages!: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(5)
  rating?: number;

  @IsOptional()
  @IsBoolean()
  isAdult?: boolean;

  @IsOptional()
  @IsBoolean()
  isNew?: boolean;

  @IsOptional()
  @IsEnum(AccessType)
  accessType?: AccessType;

  @IsOptional()
  @IsEnum(BookStatus)
  status?: BookStatus;
}

export class UpdateBookDto extends PartialType(CreateBookDto) {}

export class BlockReaderDto {
  @IsBoolean()
  isBlocked!: boolean;

  @IsOptional()
  @IsString()
  blockNote?: string;
}
