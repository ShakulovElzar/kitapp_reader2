import { IsString } from 'class-validator';

export class BookAccessDto {
  @IsString()
  bookId!: string;
}
