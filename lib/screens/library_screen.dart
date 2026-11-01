import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

enum _ShelfFilter { all, reading, finished }

/// "Текчем": every book the reader has — bought, rented, or free and opened.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _ShelfFilter _filter = _ShelfFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final books = state.libraryBooks.where((book) {
      return switch (_filter) {
        _ShelfFilter.all => true,
        _ShelfFilter.reading =>
          state.progressFor(book) > 0 && !state.isFinished(book),
        _ShelfFilter.finished => state.isFinished(book),
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Текчем', style: AppText.pageTitle),
                    const SizedBox(height: 16),
                    SegmentedButton<_ShelfFilter>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _ShelfFilter.all,
                          label: Text('Баары'),
                        ),
                        ButtonSegment(
                          value: _ShelfFilter.reading,
                          label: Text('Окуп жатам'),
                        ),
                        ButtonSegment(
                          value: _ShelfFilter.finished,
                          label: Text('Бүттү'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: books.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            switch (_filter) {
                              _ShelfFilter.all =>
                                'Текчеңиз бош. Сатып алган, ижарага алган же ачкан бекер китептериңиз ушул жерде турат.',
                              _ShelfFilter.reading =>
                                'Азыр окуп жаткан китеп жок.',
                              _ShelfFilter.finished =>
                                'Аягына чейин окулган китеп азырынча жок.',
                            },
                            textAlign: TextAlign.center,
                            style: AppText.body,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        itemCount: books.length,
                        itemBuilder: (context, index) => ShelfRow(
                          book: books[index],
                          state: state,
                          divider: index < books.length - 1,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
