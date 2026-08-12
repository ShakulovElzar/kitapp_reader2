import 'dart:convert';

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarksSheet extends StatefulWidget {
  const BookmarksSheet({
    super.key,
    required this.bookId,
    required this.onBookmarkTap,
    this.onBookmarksLoaded,
  });

  final String bookId;
  final ValueChanged<Locator> onBookmarkTap;
  final ValueChanged<List<Locator>>? onBookmarksLoaded;

  @override
  State<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<BookmarksSheet> {
  List<Locator> _bookmarks = const [];
  Map<String, String> _titles = const {};
  String _search = '';

  String get _bookmarksKey => 'bookmarks_${widget.bookId}';
  String get _titlesKey => 'bookmark_titles_${widget.bookId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = (prefs.getStringList(_bookmarksKey) ?? [])
        .map(Locator.fromJsonString)
        .whereType<Locator>()
        .toList();
    final rawTitles = prefs.getString(_titlesKey);
    final titles = <String, String>{};
    if (rawTitles != null) {
      try {
        final decoded = jsonDecode(rawTitles) as Map<String, dynamic>;
        decoded.forEach((key, value) => titles[key] = value.toString());
      } catch (_) {
        await prefs.remove(_titlesKey);
      }
    }
    if (!mounted) return;
    setState(() {
      _bookmarks = bookmarks;
      _titles = titles;
    });
    widget.onBookmarksLoaded?.call(bookmarks);
  }

  Future<void> _delete(Locator locator) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_bookmarksKey) ?? [];
    saved.removeWhere((item) => item == locator.json);
    final titles = Map<String, String>.from(_titles)..remove(locator.json);
    await Future.wait([
      prefs.setStringList(_bookmarksKey, saved),
      prefs.setString(_titlesKey, jsonEncode(titles)),
    ]);
    await _load();
  }

  Future<void> _rename(Locator locator) async {
    final controller = TextEditingController(text: _title(locator));
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Кыстарманын атын өзгөртүү'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Жокко чыгаруу'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сактоо'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final titles = Map<String, String>.from(_titles)..[locator.json] = value;
    await prefs.setString(_titlesKey, jsonEncode(titles));
    if (!mounted) return;
    setState(() => _titles = titles);
  }

  String _title(Locator locator) =>
      _titles[locator.json] ??
      locator.title ??
      '${locator.locations?.position ?? 1}-беттеги кыстарма';

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final filtered = _bookmarks
        .where((item) => _title(item).toLowerCase().contains(query))
        .toList();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F2EC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7CABB),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Артка',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                  ),
                  const Text(
                    'Кыстармалар',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Кыстармадан издөө...',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Кыстармалар жок'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final locator = filtered[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            tileColor: Colors.white.withValues(alpha: .55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(_title(locator)),
                            subtitle: Text(
                              '${locator.locations?.position ?? 1}-бет',
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onBookmarkTap(locator);
                            },
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Кыстарма аракеттери',
                              onSelected: (value) => value == 'rename'
                                  ? _rename(locator)
                                  : _delete(locator),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Атын өзгөртүү'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Өчүрүү'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
