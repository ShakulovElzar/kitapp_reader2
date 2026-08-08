import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { ReaderGuard, type TokenPayload } from '../auth/token.guard.js';
import { BookAccessDto } from './public.dto.js';
import { PublicService } from './public.service.js';

type ReaderRequest = Request & { auth: TokenPayload };

@Controller()
export class PublicController {
  constructor(private readonly service: PublicService) {}

  @Get('catalog/books')
  catalog() { return this.service.catalog(); }

  @Get('catalog/categories')
  categories() { return this.service.categories(); }

  @Get('catalog/books/:slug')
  book(@Param('slug') slug: string) { return this.service.book(slug); }

  @Post('reader/purchases')
  @UseGuards(ReaderGuard)
  buy(@Body() dto: BookAccessDto, @Req() req: ReaderRequest) {
    return this.service.buy(req.auth.sub, dto.bookId);
  }

  @Post('reader/rentals')
  @UseGuards(ReaderGuard)
  rent(@Body() dto: BookAccessDto, @Req() req: ReaderRequest) {
    return this.service.rent(req.auth.sub, dto.bookId);
  }

  @Get('reader/library')
  @UseGuards(ReaderGuard)
  library(@Req() req: ReaderRequest) {
    return this.service.library(req.auth.sub);
  }

  @Get('reader/books/:id/file')
  @UseGuards(ReaderGuard)
  file(@Param('id') id: string, @Req() req: ReaderRequest) {
    return this.service.readerFile(req.auth.sub, id);
  }
}
