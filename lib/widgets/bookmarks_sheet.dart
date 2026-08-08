import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flureadium/flureadium.dart';

class BookmarksSheet extends StatefulWidget {
  final Function(Locator locator) onBookmarkTap;

  final Function(List<Locator> bookmarks)? onBookmarksLoaded;

  const BookmarksSheet({
    super.key,
    required this.onBookmarkTap,
    this.onBookmarksLoaded,
  });

  @override
  State<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<BookmarksSheet> {
  List<Locator> _bookmarks = [];

  Map<String, String> _customTitles = {};

  static const String _bookId = 'test_epub';

  String get _bookmarksKey => 'bookmarks_$_bookId';

  String get _bookmarkTitlesKey => 'bookmark_titles_$_bookId';

  String _search = '';
  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _deleteBookmark(int index) async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getStringList(_bookmarksKey) ?? [];

    if (index >= saved.length) {
      return;
    }

    saved.removeAt(index);

    await prefs.setStringList(_bookmarksKey, saved);

    _loadBookmarks();
  }

  Future<void> _renameBookmark(Locator locator, String newTitle) async {
    final prefs = await SharedPreferences.getInstance();

    final titles = prefs.getStringList(_bookmarkTitlesKey) ?? [];

    final map = <String, String>{};

    for (final item in titles) {
      final parts = item.split('|||');

      if (parts.length >= 2) {
        map[parts[0]] = parts[1];
      }
    }

    map[locator.json] = newTitle;

    final updated = map.entries.map((e) => '${e.key}|||${e.value}').toList();

    await prefs.setStringList(_bookmarkTitlesKey, updated);

    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getStringList(_bookmarksKey) ?? [];

    final savedTitles = prefs.getStringList(_bookmarkTitlesKey) ?? [];

    final bookmarks = saved
        .map((e) => Locator.fromJsonString(e))
        .whereType<Locator>()
        .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _bookmarks = bookmarks;

      widget.onBookmarksLoaded?.call(bookmarks);

      _customTitles = {};

      for (final item in savedTitles) {
        final parts = item.split('|||');

        if (parts.length >= 2) {
          _customTitles[parts[0]] = parts[1];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _bookmarks
        .where(
          (item) => (item.title ?? 'Кыстарма').toLowerCase().contains(
            _search.toLowerCase(),
          ),
        )
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
            const SizedBox(height: 6),

            // handle
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7CABB),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // header
            SizedBox(
              height: 50,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Артка',
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Color(0xFF4A4035),
                      size: 20,
                    ),
                  ),

                  const Expanded(
                    child: Center(
                      child: Text(
                        'Кыстармалар',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A4035),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 48),
                ],
              ),
            ),

            // search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1ECE6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (value) {
                    setState(() {
                      _search = value;
                    });
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Издөө...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9A9085),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFF9A9085),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // list
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        debugPrint(item.toString());

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F6F2),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFE9DED1),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.035),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () async {
                                Navigator.pop(context);

                                await Future.delayed(
                                  const Duration(milliseconds: 120),
                                );

                                widget.onBookmarkTap(item);
                              },
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  16,
                                  18,
                                  14,
                                ),
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _customTitles[item.json] ?? 'Кыстарма',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2F2923),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${item.locations?.position ?? 1}-бет',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF8D847A),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFE7DCCF),
                                    ),

                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () async {
                                            await _deleteBookmark(index);
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.delete_outline,
                                                  size: 14,
                                                  color: Color(0xFFD15D52),
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Өчүрүү',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFFD15D52),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        const Spacer(),

                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () async {
                                            final controller =
                                                TextEditingController(
                                                  text: item.title ?? '',
                                                );

                                            final result = await showDialog<String>(
                                              context: context,
                                              builder: (context) {
                                                return Dialog(
                                                  backgroundColor: const Color(
                                                    0xFFF6F2EC,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          28,
                                                        ),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          20,
                                                          18,
                                                          20,
                                                          18,
                                                        ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 42,
                                                          height: 4,
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFFD7CABB,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                          ),
                                                        ),

                                                        const SizedBox(
                                                          height: 18,
                                                        ),

                                                        const Text(
                                                          'Атын өзгөртүү',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                              0xFF4A4035,
                                                            ),
                                                          ),
                                                        ),

                                                        const SizedBox(
                                                          height: 12,
                                                        ),

                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFFF1ECE6,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                          ),
                                                          child: TextField(
                                                            controller:
                                                                controller,
                                                            autofocus: true,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 10,
                                                                ),
                                                            decoration: const InputDecoration(
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              hintText:
                                                                  'Аталышы...',
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        20,
                                                                    vertical:
                                                                        10,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),

                                                        const SizedBox(
                                                          height: 18,
                                                        ),

                                                        Row(
                                                          children: [
                                                            InkWell(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                  context,
                                                                );
                                                              },
                                                              child: const Padding(
                                                                padding:
                                                                    EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          8,
                                                                    ),
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .close,
                                                                      size: 14,
                                                                      color: Color(
                                                                        0xFFD15D52,
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      width: 6,
                                                                    ),
                                                                    Text(
                                                                      'Жокко чыгаруу',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: Color(
                                                                          0xFFD15D52,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),

                                                            const Spacer(),

                                                            InkWell(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                  context,
                                                                  controller
                                                                      .text,
                                                                );
                                                              },
                                                              child: const Padding(
                                                                padding:
                                                                    EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          8,
                                                                    ),
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .check,
                                                                      size: 14,
                                                                      color: Color(
                                                                        0xFF8D847A,
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      width: 6,
                                                                    ),
                                                                    Text(
                                                                      'Сактоо',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: Color(
                                                                          0xFF8D847A,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );

                                            if (result != null &&
                                                result.trim().isNotEmpty) {
                                              await _renameBookmark(
                                                item,
                                                result.trim(),
                                              );
                                            }
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: 14,
                                                  color: Color(0xFF8D847A),
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Атын өзгөртүү',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF8D847A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 54,
            color: Colors.brown.withValues(alpha: 0.45),
          ),

          const SizedBox(height: 14),

          const Text(
            'Кыстармалар жок',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4035),
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Окуп жатканда\nкыстарма кошуңуз',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8D847A),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
