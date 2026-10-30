import 'dart:async';
import 'dart:convert';

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import '../theme/reader_palette.dart';
import 'contents_sheet.dart';

class SearchSheet extends StatefulWidget {
  const SearchSheet({
    super.key,
    required this.bookId,
    required this.manifestUrl,
    required this.publication,
    required this.onResultTap,
  });

  final String bookId;
  final String manifestUrl;
  final Publication publication;
  final void Function(Locator locator, String query, int occurrence)
  onResultTap;

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

  String get _recentKey =>
      AppStateScope.read(context).api.userKey('reader_searches_${widget.bookId}');

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
    ].take(10).toList();
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
                  // EPUB XHTML is UTF-8; the server sends no charset, so decode explicitly.
                  .parse(utf8.decode(response.bodyBytes, allowMalformed: true))
                  .body
                  ?.text
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim() ??
              '';
          _chapterText[link.href] = text;
        }
        var match = text.toLowerCase().indexOf(normalized);
        var occurrence = 0;
        while (match >= 0 && results.length < 100) {
          final start = (match - 55).clamp(0, text.length);
          final end = (match + query.length + 95).clamp(0, text.length);
          final locator = Locator(
            href: link.href,
            type: link.type ?? 'application/xhtml+xml',
            title: link.title,
            locations: Locations(
              progression: text.isEmpty ? 0 : match / text.length,
            ),
          );
          results.add(
            _SearchResult(
              snippet:
                  '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}',
              chapter: link.title ?? '${index + 1}-бөлүм',
              locator: locator,
              query: query,
              occurrence: occurrence,
            ),
          );
          occurrence++;
          match = text.toLowerCase().indexOf(
            normalized,
            match + normalized.length,
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

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
    if (mounted) setState(() => _recent = const []);
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
    return ReaderListScaffold(
      title: 'ИЗДӨӨ',
      child: Column(
        children: [
          const SizedBox(height: 14),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Акыркы издөөлөр',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          tooltip: 'Издөө тарыхын тазалоо',
                          onPressed: _clearRecent,
                          icon: const Icon(Icons.delete_outline, size: 18),
                        ),
                      ],
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
                          tileColor: ReaderPalette.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: _HighlightedSnippet(
                            text: result.snippet,
                            query: result.query,
                          ),
                          subtitle: Text(
                            result.chapter,
                            style: const TextStyle(color: ReaderPalette.muted),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            widget.onResultTap(
                              result.locator,
                              result.query,
                              result.occurrence,
                            );
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.snippet,
    required this.chapter,
    required this.locator,
    required this.query,
    required this.occurrence,
  });

  final String snippet;
  final String chapter;
  final Locator locator;
  final String query;
  final int occurrence;
}

class _HighlightedSnippet extends StatelessWidget {
  const _HighlightedSnippet({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) {
      return Text(text, maxLines: 4, overflow: TextOverflow.ellipsis);
    }
    final end = index + query.length;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, end),
            style: const TextStyle(
              backgroundColor: Color(0xFFFFE066),
              color: Color(0xFF111111),
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}
