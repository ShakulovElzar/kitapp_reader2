import 'package:flutter/material.dart';

import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'home_screen.dart';
import 'routes.dart';

/// "Каталог" tab: search, most read, newest, and genres as a plain list.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

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
    // "Most read" = most readers who spent at least two minutes in the book.
    final popular = books.where((book) => book.readersCount > 0).toList()
      ..sort((a, b) => b.readersCount.compareTo(a.readersCount));
    final newest = books.where((book) => book.isNew).toList();
    final categories = books.map((book) => book.category).toSet().toList()
      ..sort();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          key: const PageStorageKey('catalog'),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Каталог', style: AppText.pageTitle),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: 'Китеп же автор издөө',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => openSearch(context),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.field),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded, color: AppColors.muted),
                            SizedBox(width: 10),
                            Text(
                              'Китеп же автор',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (popular.isNotEmpty) ...[
              const SectionHeader(title: 'Көп окулгандар'),
              _CoverRow(books: popular.take(10).toList()),
            ],
            SectionHeader(
              title: 'Жаңы келгендер',
              onTap: () => openSearch(context),
            ),
            _CoverRow(
              books: (newest.isEmpty ? books : newest).take(10).toList(),
            ),
            const SectionHeader(title: 'Жанрлар'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final (index, category) in categories.indexed)
                    LinkRow(
                      title: category,
                      value:
                          '${books.where((b) => b.category == category).length}',
                      divider: index < categories.length - 1,
                      onTap: () => openSearch(context, category: category),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverRow extends StatelessWidget {
  const _CoverRow({required this.books});

  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 226,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) => BookTileCard(
          book: books[index],
          onTap: () => openBook(context, books[index]),
        ),
      ),
    );
  }
}
