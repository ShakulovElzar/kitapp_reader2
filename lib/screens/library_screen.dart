import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'book_detail_screen.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _completedOnly = false;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final books = state.libraryBooks
        .where((book) => !_completedOnly || state.progressFor(book) >= .98)
        .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Менин китептерим',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Издөө',
                  onPressed: () => showSearch(
                    context: context,
                    delegate: _LibrarySearch(state.libraryBooks),
                  ),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Баары')),
                ButtonSegment(value: true, label: Text('Окулуп бүттү')),
              ],
              selected: {_completedOnly},
              onSelectionChanged: (value) =>
                  setState(() => _completedOnly = value.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: books.isEmpty
                ? const _EmptyLibrary()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    itemCount: books.length,
                    separatorBuilder: (_, _) => const Divider(height: 22),
                    itemBuilder: (context, index) =>
                        _LibraryBookRow(book: books[index], state: state),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LibraryBookRow extends StatelessWidget {
  const _LibraryBookRow({required this.book, required this.state});

  final Book book;
  final AppStateController state;

  void _openReader(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          book: book,
          onProgress: (value) => state.setProgress(book, value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = state.progressFor(book);
    final rentalEnd = state.rentalEnd(book);
    final rented = state.isRented(book);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openReader(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(book: book, width: 78, height: 112, borderRadius: 8),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        onSelected: (value) async {
                          if (value == 'detail') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BookDetailScreen(book: book),
                              ),
                            );
                          } else if (value == 'share' && context.mounted) {
                            await Clipboard.setData(
                              ClipboardData(
                                text: Uri.base
                                    .resolve('/books/${book.slug}')
                                    .toString(),
                              ),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Китептин шилтемеси көчүрүлдү'),
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'detail',
                            child: Text('Китеп жөнүндө'),
                          ),
                          PopupMenuItem(value: 'share', child: Text('Бөлүшүү')),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    book.author,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: AppColors.line,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        progress == 0
                            ? 'Окула элек'
                            : '${(progress * 100).round()}% окулду',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      if (rented && rentalEnd != null)
                        Text(
                          '${rentalEnd.difference(DateTime.now()).inDays + 1} күн калды',
                          style: const TextStyle(
                            color: Color(0xFFB46A18),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        Text(
                          book.isFree ? 'Акысыз' : 'Сатып алынган',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: FilledButton.icon(
                      onPressed: () => _openReader(context),
                      icon: const Icon(Icons.menu_book_rounded, size: 15),
                      label: Text(progress > 0 ? 'Улантуу' : 'Окуу'),
                    ),
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

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 62, color: AppColors.green),
            SizedBox(height: 14),
            Text(
              'Китепканаңыз азырынча бош',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 5),
            Text(
              'Каталогдон китеп сатып алыңыз же акысыз китепти кошуңуз',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySearch extends SearchDelegate<Book?> {
  _LibrarySearch(this.books);

  final List<Book> books;

  @override
  String get searchFieldLabel => 'Китептен издөө';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final filtered = books.where((book) {
      final value = query.toLowerCase();
      return book.title.toLowerCase().contains(value) ||
          book.author.toLowerCase().contains(value);
    }).toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final book = filtered[index];
        return ListTile(
          leading: BookCover(
            book: book,
            width: 38,
            height: 54,
            borderRadius: 4,
          ),
          title: Text(book.title),
          subtitle: Text(book.author),
          onTap: () {
            close(context, book);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
            );
          },
        );
      },
    );
  }
}
