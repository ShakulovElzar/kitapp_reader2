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
    final books = AppStateScope.of(context).visibleBooks;
    final newest = books.where((book) => book.isNew).toList();
    final popular = [...books]..sort((a, b) => b.rating.compareTo(a.rating));
    final authors = books.reversed.toList();

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
                  for (final category in const [
                    'Баары',
                    'Роман',
                    'Поэзия',
                    'Тарыхый',
                    'Детектив',
                    'Фантастика',
                  ])
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
          _BookSection(
            title: 'Жаңы болуп чыкты',
            books: newest.isEmpty ? books.take(5).toList() : newest,
            onBookTap: (book) => _openBook(context, book),
            onAllTap: () => _openSearch(context),
          ),
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
    required this.onAllTap,
  });

  final String title;
  final List<Book> books;
  final ValueChanged<Book> onBookTap;
  final VoidCallback onAllTap;

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
