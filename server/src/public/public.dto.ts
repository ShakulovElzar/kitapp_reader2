import { IsInt, IsNumber, IsObject, IsOptional, IsString, Max, Min } from 'class-validator';

export class BookAccessDto {
  @IsString()
  bookId!: string;
}

export class ReadingProgressDto extends BookAccessDto {
  @IsNumber()
  @Min(0)
  @Max(1)
  progression!: number;

  @IsInt()
  @Min(1)
  @Max(300)
  activeSeconds!: number;

  @IsOptional()
  @IsObject()
  locator?: Record<string, unknown>;
}
