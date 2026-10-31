import 'package:flutter/material.dart';

import '../models/book.dart';
import '../state/app_state.dart';
import 'book_detail_screen.dart';
import 'catalog_search_screen.dart';
import 'library_screen.dart';
import 'phone_auth_screen.dart';
import 'reader_screen.dart';

/// Navigation shared by every screen, so each flow opens pages the same way.
void openBook(BuildContext context, Book book) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
}

void openSearch(BuildContext context, {String? category}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CatalogSearchScreen(category: category)),
  );
}

void openShelf(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const LibraryScreen()));
}

/// Opens the reader, asking a guest to sign in first.
Future<void> openReader(BuildContext context, Book book) async {
  if (!await ensureSignedIn(context) || !context.mounted) return;
  final state = AppStateScope.read(context);
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ReaderScreen(
        book: book,
        onProgress: (value) => state.setProgress(book, value),
      ),
    ),
  );
}
