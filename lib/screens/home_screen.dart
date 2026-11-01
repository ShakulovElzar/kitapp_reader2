import 'package:flutter/material.dart';

import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'phone_auth_screen.dart';
import 'routes.dart';

/// "Окуу" tab: the book you are reading comes first, with one button to
/// continue. New arrivals and the rest of your shelf follow.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final books = state.visibleBooks;
    if (state.loading && books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && books.isEmpty) {
      return ErrorRetry(message: state.error!, onRetry: state.refresh);
    }

    final current = _currentBook(state);
    final newest = books.where((book) => book.isNew).toList();
    final shelf = state.libraryBooks
        .where((book) => book.id != current?.id)
        .take(3)
        .toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Kitapp',
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Издөө',
                    onPressed: () => openSearch(context),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
            ),
            if (!state.isAuthenticated)
              const _GuestIntro()
            else if (current != null)
              _ContinueReading(book: current, state: state)
            else
              _EmptyShelf(onOpenCatalog: onOpenCatalog),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(),
            ),
            SectionHeader(
              title: 'Жаңы келгендер',
              onTap: () => openSearch(context),
            ),
            SizedBox(
              height: 226,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: (newest.isEmpty ? books : newest).take(10).length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final book = (newest.isEmpty ? books : newest)[index];
                  return BookTileCard(
                    book: book,
                    onTap: () => openBook(context, book),
                  );
                },
              ),
            ),
            if (shelf.isNotEmpty) ...[
              SectionHeader(
                title: 'Текчеңизде',
                onTap: () => openShelf(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final (index, book) in shelf.indexed)
                      ShelfRow(
                        book: book,
                        state: state,
                        compact: true,
                        divider: index < shelf.length - 1,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Last book read for a while, else the newest one on the shelf.
  Book? _currentBook(AppStateController state) {
    for (final item in state.recent) {
      if (state.showAdult || !item.book.isAdult) {
        final match = state.visibleBooks.where((b) => b.id == item.book.id);
        return match.isEmpty ? item.book : match.first;
      }
    }
    final unfinished = state.libraryBooks.where((b) => !state.isFinished(b));
    return unfinished.isEmpty ? null : unfinished.first;
  }
}

class _ContinueReading extends StatelessWidget {
  const _ContinueReading({required this.book, required this.state});

  final Book book;
  final AppStateController state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progressFor(book);
    final rentalEnd = state.isRented(book) ? state.rentalEnd(book) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            progress > 0 ? 'Окуп жатасыз' : 'Окууга даяр',
            style: AppText.label,
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => openBook(context, book),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(book: book, width: 104, height: 150, lifted: true),
                const SizedBox(width: 18),
                Expanded(
                  child: SizedBox(
                    height: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bookTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(book.author, style: AppText.meta),
                        const Spacer(),
                        if (rentalEnd != null) ...[
                          Text(
                            'Ижара ${formatDay(rentalEnd)} чейин',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.warm,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        ProgressLine(value: progress),
                        const SizedBox(height: 8),
                        Text(
                          progress > 0
                              ? '${(progress * 100).round()}% окулду'
                              : 'Окула элек',
                          style: AppText.meta,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => openReader(context, book),
            child: Text(progress > 0 ? 'Окууну улантуу' : 'Окуп баштоо'),
          ),
        ],
      ),
    );
  }
}

class _GuestIntro extends StatelessWidget {
  const _GuestIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Китептериңиз жана окуган жериңиз бир жерде',
            style: AppText.bookTitle,
          ),
          const SizedBox(height: 8),
          const Text(
            'Каталогду кирбей эле карай аласыз. Окуу же сатып алуу үчүн телефон номериңиз менен кириңиз.',
            style: AppText.body,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => ensureSignedIn(context),
            child: const Text('Кирүү'),
          ),
        ],
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Текчеңиз азырынча бош', style: AppText.bookTitle),
          const SizedBox(height: 8),
          const Text(
            'Бекер китепти ачыңыз же каталогдон тандаңыз. Ал ушул жерде турат.',
            style: AppText.body,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onOpenCatalog,
            child: const Text('Каталогду ачуу'),
          ),
        ],
      ),
    );
  }
}

/// One book on the shelf: cover, how you have it, and reading progress.
class ShelfRow extends StatelessWidget {
  const ShelfRow({
    super.key,
    required this.book,
    required this.state,
    this.compact = false,
    this.divider = true,
  });

  final Book book;
  final AppStateController state;
  final bool compact;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final progress = state.progressFor(book);
    final rentalEnd = state.isRented(book) ? state.rentalEnd(book) : null;
    final finished = state.isFinished(book);
    final ownership = book.isFree
        ? 'Бекер'
        : state.isPurchased(book)
        ? 'Сатып алынган'
        : null;
    final coverWidth = compact ? 36.0 : 52.0;

    return InkWell(
      onTap: () => openReader(context, book),
      onLongPress: () => openBook(context, book),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: AppColors.line))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(book: book, width: coverWidth, height: coverWidth * 1.5),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: compact ? null : coverWidth * 1.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 15 : 16,
                        fontWeight: compact ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rentalEnd != null
                          ? 'Ижара ${formatDay(rentalEnd)} чейин'
                          : compact
                          ? (ownership ?? book.author)
                          : [book.author, ?ownership].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: rentalEnd != null
                            ? AppColors.warm
                            : AppColors.muted,
                      ),
                    ),
                    if (!compact) ...[
                      const Spacer(),
                      if (finished)
                        const Row(
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppColors.green,
                            ),
                            SizedBox(width: 6),
                            Text('Окулуп бүттү', style: AppText.meta),
                          ],
                        )
                      else if (progress == 0)
                        const Text(
                          'Окуп баштоо',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.green,
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(child: ProgressLine(value: progress)),
                            const SizedBox(width: 10),
                            Text(
                              '${(progress * 100).round()}%',
                              style: AppText.meta,
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (compact) ...[
              const SizedBox(width: 12),
              Text(
                finished ? 'Бүттү' : '${(progress * 100).round()}%',
                style: AppText.meta,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: AppText.body),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Кайра аракет кылуу'),
            ),
          ],
        ),
      ),
    );
  }
}

const _monthsGenitive = [
  'январга',
  'февралга',
  'мартка',
  'апрелге',
  'майга',
  'июнга',
  'июлга',
  'августка',
  'сентябрга',
  'октябрга',
  'ноябрга',
  'декабрга',
];

/// "13-ноябрга" — a day and month for "until" phrases.
String formatDay(DateTime value) {
  final local = value.toLocal();
  return '${local.day}-${_monthsGenitive[local.month - 1]}';
}
