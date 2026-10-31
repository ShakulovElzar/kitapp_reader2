import 'package:flutter/material.dart';

import '../services/launch_link.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'book_detail_screen.dart';
import 'catalog_screen.dart';
import 'home_screen.dart';
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
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: IndexedStack(
            index: _index,
            children: [
              HomeScreen(onOpenCatalog: () => setState(() => _index = 1)),
              const CatalogScreen(),
              const ProfileScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _TabBar(
        index: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

/// Bottom tabs: icon and label, the active one in green. No pill indicator.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'Окуу'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Каталог'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (final (i, item) in _items.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        child: InkResponse(
                          onTap: () => onSelected(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                i == index ? item.$2 : item.$1,
                                size: 24,
                                color: i == index
                                    ? AppColors.green
                                    : AppColors.muted,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.$3,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: i == index
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: i == index
                                      ? AppColors.green
                                      : AppColors.muted,
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
          ),
        ),
      ),
    );
  }
}
