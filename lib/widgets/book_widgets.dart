import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_theme.dart';

/// Book cover with a thin paper shadow. Books without an image get a plain
/// coloured cover with the title set in Literata.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width = 104,
    this.height = 154,
    this.borderRadius = 3,
    this.lifted = false,
  });

  final Book book;
  final double width;
  final double height;
  final double borderRadius;

  /// A deeper shadow for the one large cover on a screen.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color(book.coverStart),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          const BoxShadow(
            color: Color(0x2E191B19),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          if (lifted)
            const BoxShadow(
              color: Color(0x40191B19),
              blurRadius: 30,
              spreadRadius: -12,
              offset: Offset(0, 16),
            ),
        ],
      ),
      child: book.coverUrl != null
          ? Image.network(
              book.coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _TitleCover(book: book, width: width),
            )
          : _TitleCover(book: book, width: width),
    );
  }
}

class _TitleCover extends StatelessWidget {
  const _TitleCover({required this.book, required this.width});

  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(width * .1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.serif,
              color: Colors.white,
              fontSize: (width * .14).clamp(8, 22).toDouble(),
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            book.author,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontSize: (width * .09).clamp(6, 14).toDouble(),
            ),
          ),
        ],
      ),
    );
  }
}

/// How the reader can get the book, as one short line ("Бекер", "149 сом").
String priceLabel(Book book) {
  if (book.isFree) return 'Бекер';
  if (book.canBuy) return '${book.price} сом';
  return '${book.rentalPrice} сом / ${book.rentalDays} күн';
}

/// Cover with title and price under it, for horizontal rows and grids.
class BookTileCard extends StatelessWidget {
  const BookTileCard({
    super.key,
    required this.book,
    required this.onTap,
    this.width = 100,
  });

  final Book book;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(book: book, width: width, height: width * 1.46),
            const SizedBox(height: 8),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              priceLabel(book),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: book.isFree ? AppColors.green : AppColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title with an optional "Баары" link on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: AppText.section)),
          if (onTap != null)
            TextButton(onPressed: onTap, child: const Text('Баары')),
        ],
      ),
    );
  }
}

/// Thin progress line used for reading progress everywhere.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 3,
        backgroundColor: AppColors.line,
        color: AppColors.green,
      ),
    );
  }
}

/// Plain row with a chevron, separated by a hairline: settings and lists.
class LinkRow extends StatelessWidget {
  const LinkRow({
    super.key,
    required this.title,
    required this.onTap,
    this.value,
    this.divider = true,
  });

  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: AppColors.line))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, color: AppColors.ink),
              ),
            ),
            if (value != null) ...[
              Text(value!, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
