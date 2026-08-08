import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { AdminGuard, type TokenPayload } from '../auth/token.guard.js';
import {
  BlockReaderDto,
  CreateAuthorDto,
  CreateBookDto,
  CreateCategoryDto,
  UpdateAuthorDto,
  UpdateBookDto,
  UpdateCategoryDto,
} from './admin.dto.js';
import { AdminService } from './admin.service.js';

type AdminRequest = Request & { auth: TokenPayload };

@UseGuards(AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly service: AdminService) {}

  @Get('dashboard')
  dashboard() { return this.service.dashboard(); }

  @Get('authors')
  authors() { return this.service.listAuthors(); }

  @Post('authors')
  createAuthor(@Body() dto: CreateAuthorDto, @Req() req: AdminRequest) {
    return this.service.createAuthor(dto, req.auth.sub);
  }

  @Patch('authors/:id')
  updateAuthor(@Param('id') id: string, @Body() dto: UpdateAuthorDto, @Req() req: AdminRequest) {
    return this.service.updateAuthor(id, dto, req.auth.sub);
  }

  @Delete('authors/:id')
  deleteAuthor(@Param('id') id: string, @Req() req: AdminRequest) {
    return this.service.deleteAuthor(id, req.auth.sub);
  }

  @Get('categories')
  categories() { return this.service.listCategories(); }

  @Post('categories')
  createCategory(@Body() dto: CreateCategoryDto, @Req() req: AdminRequest) {
    return this.service.createCategory(dto, req.auth.sub);
  }

  @Patch('categories/:id')
  updateCategory(@Param('id') id: string, @Body() dto: UpdateCategoryDto, @Req() req: AdminRequest) {
    return this.service.updateCategory(id, dto, req.auth.sub);
  }

  @Delete('categories/:id')
  deleteCategory(@Param('id') id: string, @Req() req: AdminRequest) {
    return this.service.deleteCategory(id, req.auth.sub);
  }

  @Get('books')
  books() { return this.service.listBooks(); }

  @Post('books')
  createBook(@Body() dto: CreateBookDto, @Req() req: AdminRequest) {
    return this.service.createBook(dto, req.auth.sub);
  }

  @Patch('books/:id')
  updateBook(@Param('id') id: string, @Body() dto: UpdateBookDto, @Req() req: AdminRequest) {
    return this.service.updateBook(id, dto, req.auth.sub);
  }

  @Delete('books/:id')
  deleteBook(@Param('id') id: string, @Req() req: AdminRequest) {
    return this.service.deleteBook(id, req.auth.sub);
  }

  @Post('books/:id/files')
  @UseInterceptors(
    FileFieldsInterceptor([
      { name: 'cover', maxCount: 1 },
      { name: 'epub', maxCount: 1 },
    ], { limits: { fileSize: 50 * 1024 * 1024 } }),
  )
  uploadBookFiles(
    @Param('id') id: string,
    @UploadedFiles() files: { cover?: Express.Multer.File[]; epub?: Express.Multer.File[] },
    @Req() req: AdminRequest,
  ) {
    return this.service.uploadBookFiles(id, files, req.auth.sub);
  }

  @Get('readers')
  readers() { return this.service.listReaders(); }

  @Patch('readers/:id/block')
  blockReader(
    @Param('id') id: string,
    @Body() dto: BlockReaderDto,
    @Req() req: AdminRequest,
  ) {
    return this.service.blockReader(id, dto, req.auth.sub);
  }

  @Get('purchases')
  purchases() { return this.service.listPurchases(); }

  @Get('rentals')
  rentals() { return this.service.listRentals(); }

  @Get('reports/sales')
  salesReport(@Query('from') from?: string, @Query('to') to?: string) {
    return this.service.salesReport(from, to);
  }

  @Get('audit-logs')
  auditLogs() { return this.service.auditLogs(); }
}
