import 'package:flutter/material.dart';

import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'book_detail_screen.dart';
import 'catalog_search_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  void _openBook(BuildContext context, Book book) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
  }

  void _openSearch(BuildContext context, {String? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatalogSearchScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final books = state.visibleBooks;
    if (state.loading && books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: state.refresh,
                child: const Text('Кайра аракет кылуу'),
              ),
            ],
          ),
        ),
      );
    }
    final newest = books.where((book) => book.isNew).toList();
    // "Most read" = most readers who spent at least two minutes in the book.
    final popular = books.where((book) => book.readersCount > 0).toList()
      ..sort((a, b) => b.readersCount.compareTo(a.readersCount));
    final authors = books.reversed.toList();
    final categories = books.map((book) => book.category).toSet().toList()
      ..sort();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey('catalog'),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Kitapp',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Издөө',
                    onPressed: () => _openSearch(context),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openSearch(context),
                child: const IgnorePointer(
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.muted,
                      ),
                      hintText: 'Китеп же авторду издеңиз',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                      suffixIcon: Icon(
                        Icons.tune_rounded,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                children: [
                  for (final category in ['Баары', ...categories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        side: BorderSide.none,
                        backgroundColor: category == 'Баары'
                            ? AppColors.green
                            : AppColors.surface,
                        labelStyle: TextStyle(
                          color: category == 'Баары'
                              ? Colors.white
                              : AppColors.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        label: Text(category),
                        onPressed: () => _openSearch(
                          context,
                          category: category == 'Баары' ? null : category,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (state.recent.isNotEmpty)
            _BookSection(
              title: 'Окууну улантуу',
              books: state.recent.map((item) => item.book).toList(),
              onBookTap: (book) => _openBook(context, book),
            ),
          _BookSection(
            title: 'Жаңы болуп чыкты',
            books: newest.isEmpty ? books.take(5).toList() : newest,
            onBookTap: (book) => _openBook(context, book),
            onAllTap: () => _openSearch(context),
          ),
          if (popular.isNotEmpty)
            _BookSection(
              title: 'Эң көп окулгандар',
              books: popular.take(7).toList(),
              onBookTap: (book) => _openBook(context, book),
              onAllTap: () => _openSearch(context),
            ),
          _BookSection(
            title: 'Жаңы авторлор',
            books: authors.take(7).toList(),
            onBookTap: (book) => _openBook(context, book),
            onAllTap: () => _openSearch(context),
          ),
          _BookSection(
            title: 'Ислам',
            books: books.where((book) => book.category == 'Дин').isEmpty
                ? books.skip(3).take(6).toList()
                : books.where((book) => book.category == 'Дин').toList(),
            onBookTap: (book) => _openBook(context, book),
            onAllTap: () => _openSearch(context, category: 'Дин'),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
        ],
      ),
    );
  }
}

class _BookSection extends StatelessWidget {
  const _BookSection({
    required this.title,
    required this.books,
    required this.onBookTap,
    this.onAllTap,
  });

  final String title;
  final List<Book> books;
  final ValueChanged<Book> onBookTap;
  final VoidCallback? onAllTap;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, onTap: onAllTap),
          SizedBox(
            height: 256,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final book = books[index];
                return BookTileCard(book: book, onTap: () => onBookTap(book));
              },
            ),
          ),
        ],
      ),
    );
  }
}
