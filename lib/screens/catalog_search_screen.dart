import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'book_detail_screen.dart';

enum PriceFilter { all, free, underThreeHundred, overThreeHundred }

class CatalogSearchScreen extends StatefulWidget {
  const CatalogSearchScreen({super.key, this.category});

  final String? category;

  @override
  State<CatalogSearchScreen> createState() => _CatalogSearchScreenState();
}

class _CatalogSearchScreenState extends State<CatalogSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String? _category;
  PriceFilter _price = PriceFilter.all;
  bool _onlyAvailable = false;
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _recent = prefs.getStringList('catalog_searches') ?? []);
  }

  Future<void> _saveQuery(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    final updated = [
      normalized,
      ..._recent.where((item) => item != normalized),
    ].take(5).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('catalog_searches', updated);
    if (mounted) setState(() => _recent = updated);
  }

  List<Book> _filterBooks(AppStateController state) {
    return state.visibleBooks.where((book) {
      final query = _query.trim().toLowerCase();
      if (query.isNotEmpty &&
          !book.title.toLowerCase().contains(query) &&
          !book.author.toLowerCase().contains(query)) {
        return false;
      }
      if (_category != null && book.category != _category) return false;
      if (_onlyAvailable && !state.hasAccess(book)) return false;
      switch (_price) {
        case PriceFilter.all:
          return true;
        case PriceFilter.free:
          return book.isFree;
        case PriceFilter.underThreeHundred:
          return !book.isFree && book.price <= 300;
        case PriceFilter.overThreeHundred:
          return book.price > 300;
      }
    }).toList();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_SearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        categories: AppStateScope.of(
          context,
        ).visibleBooks.map((book) => book.category).toSet().toList()..sort(),
        initial: _SearchFilters(
          category: _category,
          price: _price,
          onlyAvailable: _onlyAvailable,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _category = result.category;
      _price = result.price;
      _onlyAvailable = result.onlyAvailable;
    });
  }

  void _setQuery(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value);
    _saveQuery(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final books = _filterBooks(state);
    final hasFilters =
        _category != null || _price != PriceFilter.all || _onlyAvailable;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Китептер',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: TextField(
                  controller: _controller,
                  autofocus: widget.category == null,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  onSubmitted: _saveQuery,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Китеп же авторду издеңиз',
                    suffixIcon: IconButton(
                      tooltip: 'Фильтр',
                      onPressed: _openFilters,
                      icon: Badge(
                        isLabelVisible: hasFilters,
                        child: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_query.isEmpty && _recent.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: Row(
                    children: [
                      const Text(
                        'Акыркы издөөлөр',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _recent
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      label: Text(item),
                                      onPressed: () => _setQuery(item),
                                      side: BorderSide.none,
                                      labelStyle: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _category ?? 'Бардык китептер',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${books.length} китеп',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: books.isEmpty
                    ? const _EmptySearch()
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 18,
                              crossAxisSpacing: 18,
                              childAspectRatio: .53,
                            ),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return LayoutBuilder(
                            builder: (context, constraints) => BookTileCard(
                              book: book,
                              width: constraints.maxWidth,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookDetailScreen(book: book),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 52, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'Китеп табылган жок',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'Издөө сөзүн же фильтрлерди өзгөртүп көрүңүз',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFilters {
  const _SearchFilters({
    this.category,
    required this.price,
    required this.onlyAvailable,
  });

  final String? category;
  final PriceFilter price;
  final bool onlyAvailable;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.categories});

  final _SearchFilters initial;
  final List<String> categories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _category = widget.initial.category;
  late PriceFilter _price = widget.initial.price;
  late bool _onlyAvailable = widget.initial.onlyAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Фильтр',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Категория',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: <String?>[null, ...widget.categories]
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category ?? 'Баары'),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            const Text(
              'Баанын диапазону',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            RadioGroup<PriceFilter>(
              groupValue: _price,
              onChanged: (value) => setState(() => _price = value!),
              child: const Column(
                children: [
                  RadioListTile(
                    value: PriceFilter.all,
                    title: Text('Баары'),
                    dense: true,
                  ),
                  RadioListTile(
                    value: PriceFilter.free,
                    title: Text('Акысыз'),
                    dense: true,
                  ),
                  RadioListTile(
                    value: PriceFilter.underThreeHundred,
                    title: Text('300 сомго чейин'),
                    dense: true,
                  ),
                  RadioListTile(
                    value: PriceFilter.overThreeHundred,
                    title: Text('300 сомдон жогору'),
                    dense: true,
                  ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Менин китептерим гана'),
              subtitle: const Text('Сатып алынган жана ижарадагы китептер'),
              value: _onlyAvailable,
              onChanged: (value) => setState(() => _onlyAvailable = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _category = null;
                      _price = PriceFilter.all;
                      _onlyAvailable = false;
                    }),
                    child: const Text('Тазалоо'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _SearchFilters(
                        category: _category,
                        price: _price,
                        onlyAvailable: _onlyAvailable,
                      ),
                    ),
                    child: const Text('Колдонуу'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
