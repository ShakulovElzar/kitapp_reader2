import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';
import 'package:flutter/services.dart';

class SearchSheet extends StatefulWidget {
  final Publication publication;

  final Function(Locator locator) onBookmarkTap;

  const SearchSheet({
    super.key,
    required this.publication,
    required this.onBookmarkTap,
  });

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  String _search = '';

  final List<String> _recentSearches = [
    'бран',
    'дейенерис',
    'джон',
    'красный замок',
  ];

  bool _isSearching = false;

  List<Map<String, dynamic>> _results = [];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF6F2EC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),

      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,

        child: SafeArea(
          top: false,
          bottom: false,

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

              const SizedBox(height: 8),

              // header
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Артка',
                      onPressed: () async {
                        FocusScope.of(context).unfocus();

                        await Future.delayed(const Duration(milliseconds: 120));

                        await SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.immersiveSticky,
                        );

                        if (!context.mounted) {
                          return;
                        }

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
                          'Издөө',
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
                    focusNode: FocusNode()
                      ..addListener(() {
                        Future.delayed(const Duration(milliseconds: 120), () {
                          SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.immersiveSticky,
                          );
                        });
                      }),

                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (value) async {
                      setState(() {
                        _search = value;
                      });

                      if (value.trim().isEmpty) {
                        setState(() {
                          _results = [];
                        });

                        return;
                      }

                      await _searchBook(value);
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Китептен издөө...',
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
              if (_search.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 15, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Акыркы издөөлөр',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4A4035),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _recentSearches.map((item) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _search = item;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1ECE6),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE7DCCF),
                                ),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4A4035),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: _search.isEmpty
                    ? _buildEmpty()
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Натыйжалар: ${_results.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF8D847A),
                                ),
                              ),
                            ),
                          ),

                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final item = _results[index];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9F6F2),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: const Color(0xFFE9DED1),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: () {
                                        final locator =
                                            item['locator'] as Locator?;

                                        if (locator == null) {
                                          return;
                                        }

                                        widget.onBookmarkTap(locator);

                                        FocusScope.of(context).unfocus();

                                        SystemChrome.setEnabledSystemUIMode(
                                          SystemUiMode.immersiveSticky,
                                        );

                                        Navigator.pop(context);
                                      },

                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          18,
                                          16,
                                          18,
                                          16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['text'],
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF2F2923),
                                                height: 1.4,
                                              ),
                                            ),

                                            const SizedBox(height: 10),

                                            Text(
                                              '${item['page']}-бет',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF8D847A),
                                              ),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _searchBook(String query) async {
    if (_isSearching) {
      return;
    }

    _isSearching = true;

    try {
      debugPrint(
        'READING ORDER COUNT: '
        '${widget.publication.readingOrder.length}',
      );

      final results = <Map<String, dynamic>>[];

      for (final link in widget.publication.readingOrder) {
        debugPrint(
          'LINK → '
          '${link.title} '
          '${link.href}',
        );

        try {
          final locator = widget.publication.locatorFromLink(link);

          debugPrint(
            'LOCATOR → '
            '${locator?.json}',
          );

          if (locator == null) {
            continue;
          }

          final href = link.href.toLowerCase();

          if (href.contains(query.toLowerCase())) {
            results.add({
              'text': link.href,
              'page': locator.locations?.position ?? 0,
              'locator': locator,
            });
          }
        } catch (e) {
          debugPrint('SEARCH ERROR → $e');
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
      });
    } finally {
      _isSearching = false;
    }
  }

  Widget _buildEmpty() {
    return const Center(child: Text(''));
  }
}
