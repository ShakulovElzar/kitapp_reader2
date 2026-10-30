import 'package:flutter/material.dart';

import '../services/launch_link.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'book_detail_screen.dart';
import 'catalog_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// Book slug from a shared `?book=<slug>` link, opened once the catalog loads.
  String? _sharedSlug = launchUrl()?.queryParameters['book'];
  AppStateController? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.read(context);
    if (_state != state) {
      _state?.removeListener(_openSharedBook);
      _state = state..addListener(_openSharedBook);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSharedBook());
    }
  }

  @override
  void dispose() {
    _state?.removeListener(_openSharedBook);
    super.dispose();
  }

  void _openSharedBook() {
    final slug = _sharedSlug;
    final state = _state;
    if (slug == null || state == null || !mounted) return;
    final matches = state.visibleBooks.where((book) => book.slug == slug);
    if (matches.isEmpty) {
      // Give up once the catalog has loaded without the book.
      if (!state.loading && state.visibleBooks.isNotEmpty) _sharedSlug = null;
      return;
    }
    _sharedSlug = null;
    final book = matches.first;
    // Wait until the app's first navigation settles, or the route gets replaced.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: Colors.white,
            child: IndexedStack(
              index: _index,
              children: const [
                CatalogScreen(),
                LibraryScreen(),
                ProfileScreen(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: NavigationBar(
            height: 68,
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.green,
                ),
                label: 'Категориялар',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.green,
                ),
                label: 'Башкы китептер',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(
                  Icons.person_rounded,
                  color: AppColors.green,
                ),
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
