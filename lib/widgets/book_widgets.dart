import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_theme.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width = 104,
    this.height = 154,
    this.borderRadius = 10,
  });

  final Book book;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(book.coverStart), Color(book.coverEnd)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (book.coverUrl != null)
            Positioned.fill(
              child: Image.network(
                book.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (book.coverUrl == null) ...[
            Positioned(
              right: -width * .28,
              bottom: height * .08,
              child: Container(
                width: width * .85,
                height: width * .85,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
              ),
            ),
            Positioned(
              left: width * .12,
              right: width * .12,
              top: height * .12,
              child: Text(
                book.author.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: width * .065,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .5,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: width * .08),
                child: Text(
                  book.coverMark,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Georgia',
                    fontSize: width * .18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    shadows: const [
                      Shadow(color: Colors.black38, blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: width * .16,
              right: width * .16,
              bottom: height * .1,
              child: Container(height: 1, color: Colors.white38),
            ),
          ],
        ],
      ),
    );
  }
}

class BookTileCard extends StatelessWidget {
  const BookTileCard({
    super.key,
    required this.book,
    required this.onTap,
    this.width = 116,
  });

  final Book book;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(book: book, width: width, height: width * 1.45),
              const SizedBox(height: 8),
              SizedBox(
                height: 31,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 13,
                      height: 1.16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      book.isFree
                          ? 'Акысыз'
                          : book.canBuy
                          ? '${book.price} сом'
                          : 'Ижара: ${book.rentalPrice} сом',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (book.isNew) ...[
                    const Text(
                      'Жаңы',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: const Text('Баарын көрүү', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
