import 'dart:async';

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SearchSheet extends StatefulWidget {
  const SearchSheet({
    super.key,
    required this.bookId,
    required this.manifestUrl,
    required this.publication,
    required this.onBookmarkTap,
  });

  final String bookId;
  final String manifestUrl;
  final Publication publication;
  final ValueChanged<Locator> onBookmarkTap;

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final Map<String, String> _chapterText = {};
  List<String> _recent = const [];
  List<_SearchResult> _results = const [];
  Timer? _debounce;
  bool _isSearching = false;
  int _searchGeneration = 0;

  String get _recentKey => 'reader_searches_${widget.bookId}';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _recent = prefs.getStringList(_recentKey) ?? []);
    }
  }

  Future<void> _saveRecent(String query) async {
    final updated = [
      query,
      ..._recent.where((item) => item != query),
    ].take(5).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, updated);
    if (mounted) setState(() => _recent = updated);
  }

  void _queueSearch(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(query));
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    setState(() => _isSearching = true);
    final normalized = query.toLowerCase();
    final results = <_SearchResult>[];
    try {
      for (
        var index = 0;
        index < widget.publication.readingOrder.length;
        index++
      ) {
        final link = widget.publication.readingOrder[index];
        var text = _chapterText[link.href];
        if (text == null) {
          final uri = Uri.parse(widget.manifestUrl).resolve(link.href);
          final response = await http.get(uri);
          if (response.statusCode != 200) continue;
          text =
              html_parser
                  .parse(response.body)
                  .body
                  ?.text
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim() ??
              '';
          _chapterText[link.href] = text;
        }
        final match = text.toLowerCase().indexOf(normalized);
        if (match < 0) continue;
        final start = (match - 55).clamp(0, text.length);
        final end = (match + query.length + 95).clamp(0, text.length);
        final locator = widget.publication.locatorFromLink(link);
        if (locator != null) {
          results.add(
            _SearchResult(
              snippet:
                  '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}',
              chapter: link.title ?? '${index + 1}-бөлүм',
              locator: locator,
            ),
          );
        }
        if (results.length >= 50) break;
      }
      await _saveRecent(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _results = results);
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _runRecent(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _search(query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Издөө',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                onChanged: _queueSearch,
                onSubmitted: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Китептин текстинен издөө...',
                ),
              ),
            ),
            if (_controller.text.isEmpty && _recent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'Акыркы издөөлөр',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      ..._recent.map(
                        (item) => Semantics(
                          button: true,
                          label: 'Акыркы издөө: $item',
                          child: ActionChip(
                            label: Text(item),
                            onPressed: () => _runRecent(item),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isSearching) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : _results.isEmpty && !_isSearching
                  ? const Center(child: Text('Натыйжа табылган жок'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            tileColor: Colors.white.withValues(alpha: .55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              result.snippet,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(result.chapter),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              widget.onBookmarkTap(result.locator);
                              Navigator.pop(context);
                            },
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

class _SearchResult {
  const _SearchResult({
    required this.snippet,
    required this.chapter,
    required this.locator,
  });

  final String snippet;
  final String chapter;
  final Locator locator;
}
