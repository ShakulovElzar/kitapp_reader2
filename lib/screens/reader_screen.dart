import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flureadium/flureadium.dart';
import 'package:http/http.dart' as http;

import '../models/book.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/reader_menu.dart';
import '../widgets/settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/reader_swipe_bridge.dart';
import '../services/reader_content_bridge.dart';
import '../widgets/contents_sheet.dart';
import '../widgets/bookmarks_sheet.dart';
import '../widgets/search_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.book, this.onProgress});

  final Book book;
  final ValueChanged<double>? onProgress;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  final Flureadium _flureadium = Flureadium();

  Publication? _publication;

  Object? _loadError;

  String? _manifestUrl;
  ApiClient? _api;
  Timer? _readingTimer;
  int _unsyncedActiveSeconds = 0;
  bool _isActive = true;

  int _fontSize = 120;

  double _pageMargins = 20;

  double _lineHeight = 1.5;

  bool _wordWrap = true;

  double _brightness = 1.0;

  double _sliderProgress = 0.0;

  bool _isDraggingSlider = false;

  Locator? _currentLocator;
  Locator? _initialLocator;

  int _currentPage = 1;

  int _totalPages = 1;

  int _previewPage = 1;

  List<Locator> _pageLocators = const [];

  final List<Locator> _backHistory = [];

  final List<Locator> _forwardHistory = [];

  String get _bookId => widget.book.id;

  String get _locatorKey => 'locator_$_bookId';

  String get _pageKey => 'reader_page_$_bookId';

  String get _bookmarksKey => 'bookmarks_$_bookId';

  bool _showMenu = false;

  bool _isBookmarked = false;

  Timer? _menuTimer;

  double _horizontalDragDelta = 0;
  bool _didNavigateDrag = false;

  // sepia default
  Color _backgroundColor = const Color(0xFFF4E7D3);

  Color _textColor = const Color(0xFF3E2F22);

  String _selectedTheme = 'sepia';

  List<Link> _tableOfContents = [];

  List<Locator> _bookmarks = [];

  bool _bookmarkMode = false;

  Locator? _preBookmarkLocator;

  int? _returnPage;

  int _bookmarkStartPage = 1;

  int _currentBookmarkIndex = 0;

  bool _isBookmarkNavigation = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    registerReaderSwipeBridge(
      onForward: () => unawaited(_flureadium.goRight()),
      onBackward: () => unawaited(_flureadium.goLeft()),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _api = AppStateScope.of(context).api;
      await _loadReaderPreferences();
      await _openBook();
      _startReadingTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isActive = state == AppLifecycleState.resumed;
    if (!_isActive) unawaited(_syncReadingProgress());
  }

  Future<void> _loadReaderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('reader_theme') ?? 'sepia';
    _fontSize = prefs.getInt('reader_font_size') ?? 120;
    _brightness = prefs.getDouble('reader_brightness') ?? 1.0;
    _pageMargins = prefs.getDouble('reader_page_margins') ?? 20;
    _lineHeight = prefs.getDouble('reader_line_height') ?? 1.5;
    _wordWrap = prefs.getBool('reader_word_wrap') ?? true;
    _selectedTheme = theme;
    if (theme == 'light') {
      _backgroundColor = Colors.white;
      _textColor = Colors.black;
    } else if (theme == 'dark') {
      _backgroundColor = const Color(0xFF111111);
      _textColor = const Color(0xFFB8B8B8);
    } else {
      _backgroundColor = const Color(0xFFF4E7D3);
      _textColor = const Color(0xFF3E2F22);
    }
  }

  Future<void> _saveReaderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('reader_font_size', _fontSize),
      prefs.setDouble('reader_brightness', _brightness),
      prefs.setString('reader_theme', _selectedTheme),
      prefs.setDouble('reader_page_margins', _pageMargins),
      prefs.setDouble('reader_line_height', _lineHeight),
      prefs.setBool('reader_word_wrap', _wordWrap),
    ]);
  }

  Future<void> _openBook() async {
    if (mounted) {
      setState(() {
        _publication = null;
        _loadError = null;
      });
    }

    try {
      if (kIsWeb) {
        final savedLocator = await _loadSavedLocator();
        final manifestUrl = await _api!.bookManifest(_bookId);
        final response = await http.get(Uri.parse(manifestUrl));
        if (response.statusCode != 200) {
          throw StateError('EPUB манифести жүктөлгөн жок');
        }
        final manifest = jsonDecode(response.body) as Map<String, dynamic>;
        final pageLocators =
            (manifest['pageList'] as List<dynamic>? ?? const [])
                .map(
                  (item) =>
                      Locator.fromJson(Map<String, dynamic>.from(item as Map)),
                )
                .whereType<Locator>()
                .map(_relativeLocator)
                .toList();
        final manifestToc = (manifest['toc'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .where((item) => item['href'] is String)
            .map(
              (item) => Link(
                href: item['href'] as String,
                type: item['type'] as String? ?? 'application/xhtml+xml',
                title: item['title'] as String?,
              ),
            )
            .toList();
        final prefs = await SharedPreferences.getInstance();
        final savedPage = prefs.getInt(_pageKey);

        final links = manifest['links'] as List<dynamic>;

        (links.first as Map<String, dynamic>)['href'] = manifestUrl;

        final parsedPublication = Publication.fromJson(manifest);

        if (parsedPublication == null) {
          throw StateError('Invalid web publication manifest');
        }

        final publication = parsedPublication.copyWith(
          links: [
            Link(
              href: manifestUrl,
              type: 'application/webpub+json',
              rels: const ['self'],
            ),
          ],
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _publication = publication;
          _manifestUrl = manifestUrl;
          _initialLocator = savedLocator == null
              ? (savedPage != null && pageLocators.isNotEmpty
                    ? pageLocators[(savedPage - 1).clamp(
                        0,
                        pageLocators.length - 1,
                      )]
                    : null)
              : _relativeLocator(savedLocator);
          _tableOfContents = publication.tableOfContents.isNotEmpty
              ? publication.tableOfContents
              : manifestToc;
          _pageLocators = pageLocators;
          _totalPages = pageLocators.isEmpty ? 1 : pageLocators.length;
          _currentPage = (savedPage ?? 1).clamp(1, _totalPages);
          _previewPage = _currentPage;
          _sliderProgress = _pageProgress(_currentPage);
        });

        return;
      }

      final bytes = await rootBundle.load('assets/books/test.epub');

      final tempFile = File('${Directory.systemTemp.path}/test.epub');

      await tempFile.writeAsBytes(bytes.buffer.asUint8List());

      final savedLocator = await _loadSavedLocator();
      final publication = await _flureadium.openPublication(tempFile.path);

      debugPrint(publication.toString());

      debugPrint(publication.toString());

      if (!mounted) {
        return;
      }

      setState(() {
        _publication = publication;
        _initialLocator = savedLocator;

        _tableOfContents = publication.tableOfContents;
      });

      debugPrint(publication.runtimeType.toString());
    } catch (e) {
      debugPrint('ERROR: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = e;
      });
    }
  }

  void _startReadingTimer() {
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isActive || _publication == null || _currentLocator == null) return;
      _unsyncedActiveSeconds++;
      if (_unsyncedActiveSeconds >= 30) unawaited(_syncReadingProgress());
    });
  }

  Future<void> _syncReadingProgress() async {
    final seconds = _unsyncedActiveSeconds;
    final locator = _currentLocator;
    if (seconds == 0 || locator == null || _api == null) return;
    _unsyncedActiveSeconds = 0;
    try {
      await _api!.saveProgress(
        bookId: _bookId,
        progression: locator.locations?.totalProgression ?? _sliderProgress,
        activeSeconds: seconds,
        locator: jsonDecode(locator.json) as Map<String, dynamic>,
      );
    } catch (_) {
      _unsyncedActiveSeconds += seconds;
    }
  }

  Future<Locator?> _loadSavedLocator() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final json = prefs.getString(_locatorKey);

      if (json == null) {
        return null;
      }

      return Locator.fromJsonString(json);
    } catch (e) {
      debugPrint('LOAD LOCATOR ERROR: $e');

      return null;
    }
  }

  String _relativeHref(String href) {
    final manifestUrl = _manifestUrl;
    if (manifestUrl == null) return href.replaceFirst(RegExp(r'^/'), '');
    final base = Uri.parse(manifestUrl).resolve('.');
    final target = Uri.parse(href);
    if (!target.hasScheme) return href.replaceFirst(RegExp(r'^/'), '');
    if (target.scheme != base.scheme || target.authority != base.authority) {
      return href;
    }
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    if (!target.path.startsWith(basePath)) return href;
    final relative = target.path.substring(basePath.length);
    return target.fragment.isEmpty ? relative : '$relative#${target.fragment}';
  }

  Locator _relativeLocator(Locator locator) {
    final value = jsonDecode(locator.json) as Map<String, dynamic>;
    value['href'] = _relativeHref(locator.href);
    return Locator.fromJson(value)!;
  }

  String _resourceHref(String href) {
    final relative = _relativeHref(href).split('#').first;
    return relative.replaceFirst(RegExp(r'^\./|^/'), '');
  }

  int _pageForHref(String href) {
    if (_pageLocators.isEmpty) return 1;
    final resource = _resourceHref(href);
    final index = _pageLocators.indexWhere(
      (candidate) => _resourceHref(candidate.href) == resource,
    );
    return index < 0 ? 1 : index + 1;
  }

  String? _locatorFragment(Locator locator) {
    final uriFragment = Uri.tryParse(locator.href)?.fragment;
    if (uriFragment != null && uriFragment.isNotEmpty) return uriFragment;
    final fragments = locator.locations?.fragments;
    return fragments == null || fragments.isEmpty ? null : fragments.first;
  }

  int _pageForLocator(Locator locator) {
    if (_pageLocators.isEmpty) {
      final position = locator.locations?.position;
      return (position ?? 1).clamp(1, _totalPages);
    }
    final resource = _resourceHref(locator.href);
    final progression = locator.locations?.progression ?? 0;
    var best = -1;
    for (var index = 0; index < _pageLocators.length; index++) {
      final candidate = _pageLocators[index];
      if (_resourceHref(candidate.href) != resource) continue;
      best = index;
      final candidateProgression = candidate.locations?.progression ?? 0;
      if (candidateProgression > progression) {
        return (index).clamp(1, _totalPages);
      }
    }
    if (best >= 0) return best + 1;
    final totalProgression = locator.locations?.totalProgression;
    if (totalProgression != null) {
      return (totalProgression * (_totalPages - 1)).round() + 1;
    }
    return _currentPage;
  }

  double _pageProgress(int page) {
    if (_totalPages <= 1) return 0;
    return (page - 1) / (_totalPages - 1);
  }

  Future<void> _navigateTo(
    Locator locator, {
    bool rememberHistory = true,
    String? searchQuery,
    int searchOccurrence = 0,
  }) async {
    if (rememberHistory && _currentLocator != null) {
      _backHistory.add(_currentLocator!);
      _forwardHistory.clear();
    }
    final target = _relativeLocator(locator);
    await _flureadium.goToLocator(target);
    await Future.delayed(const Duration(milliseconds: 180));
    await _flureadium.goToLocator(target);
    await Future.delayed(const Duration(milliseconds: 80));
    goToReaderFragment(_locatorFragment(target));
    if (searchQuery != null) {
      highlightReaderSearch(searchQuery, searchOccurrence);
    } else {
      clearReaderSearchHighlight();
    }
    await _rememberLocator(target);
    if (mounted) setState(() {});
  }

  Future<void> _goBackInReader() async {
    if (_backHistory.isEmpty) return;
    if (_currentLocator != null) _forwardHistory.add(_currentLocator!);
    final target = _backHistory.removeLast();
    await _navigateTo(target, rememberHistory: false);
  }

  Future<void> _goForwardInReader() async {
    if (_forwardHistory.isEmpty) return;
    if (_currentLocator != null) _backHistory.add(_currentLocator!);
    final target = _forwardHistory.removeLast();
    await _navigateTo(target, rememberHistory: false);
  }

  void _subscribeToChannels() {
    _flureadium.onTextLocatorChanged.listen((locator) {
      debugPrint(
        'FRAGMENTS: '
        '${locator.locations?.fragments}',
      );

      final page = _pageForLocator(locator);
      final progress = _pageLocators.isEmpty
          ? locator.locations?.totalProgression ?? 0.0
          : _pageProgress(page);

      if (!mounted) {
        return;
      }

      _saveLocator(locator, page: page);
      widget.onProgress?.call(progress);

      setState(() {
        _currentLocator = locator;
        _currentPage = page;

        if (_bookmarkMode) {
          _showMenu = false;

          if (_isBookmarkNavigation) {
            Future.delayed(const Duration(milliseconds: 800), () {
              _isBookmarkNavigation = false;
            });
          } else {
            final moved = (_currentPage - _bookmarkStartPage).abs();

            if (moved >= 10) {
              _bookmarkMode = false;

              _preBookmarkLocator = null;

              _returnPage = null;
            }
          }
        }

        debugPrint(
          'POSITION PAGE → '
          '$_currentPage',
        );

        if (!_isDraggingSlider) {
          _sliderProgress = progress;
        }
      });

      _checkBookmarkStatus();
    });
  }

  Future<void> _checkBookmarkStatus() async {
    if (_currentLocator == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final bookmarks = prefs.getStringList(_bookmarksKey) ?? [];

    final exists = bookmarks
        .map(Locator.fromJsonString)
        .whereType<Locator>()
        .any((locator) => _pageForLocator(locator) == _currentPage);

    if (!mounted) {
      return;
    }

    setState(() {
      _isBookmarked = exists;
    });
  }

  Future<void> _addBookmark() async {
    if (_currentLocator == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final bookmarks = prefs.getStringList(_bookmarksKey) ?? [];

    final existing = bookmarks.indexWhere((value) {
      final locator = Locator.fromJsonString(value);
      return locator != null && _pageForLocator(locator) == _currentPage;
    });

    if (existing >= 0) {
      final locatorJson = bookmarks.removeAt(existing);

      await prefs.setStringList(_bookmarksKey, bookmarks);

      final rawTitles = prefs.getString('bookmark_titles_$_bookId');
      if (rawTitles != null) {
        final titles = Map<String, dynamic>.from(jsonDecode(rawTitles) as Map);
        titles.remove(locatorJson);
        await prefs.setString('bookmark_titles_$_bookId', jsonEncode(titles));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isBookmarked = false;
      });

      return;
    }

    final value = jsonDecode(_currentLocator!.json) as Map<String, dynamic>;
    final locations = Map<String, dynamic>.from(
      value['locations'] as Map? ?? const {},
    );
    locations['position'] = _currentPage;
    locations['totalProgression'] = _pageProgress(_currentPage);
    value['locations'] = locations;
    final bookmark = Locator.fromJson(value)!;
    bookmarks.add(bookmark.json);

    await prefs.setStringList(_bookmarksKey, bookmarks);

    if (!mounted) {
      return;
    }

    setState(() {
      _isBookmarked = true;
    });
  }

  Future<void> _saveLocator(Locator locator, {int? page}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_locatorKey, locator.json);
      await prefs.setInt(_pageKey, page ?? _pageForLocator(locator));

      debugPrint('LOCATOR SAVED');
    } catch (e) {
      debugPrint('SAVE LOCATOR ERROR: $e');
    }
  }

  Future<void> _rememberLocator(Locator locator) async {
    if (mounted) {
      setState(() => _currentLocator = locator);
    }
    await _saveLocator(locator);
  }

  Future<void> _applyReaderStyle() async {
    await _flureadium.setEPUBPreferences(
      EPUBPreferences(
        fontFamily: 'Georgia',

        fontSize: _fontSize,

        fontWeight: null,

        verticalScroll: false,

        backgroundColor: _backgroundColor,

        textColor: _textColor,
        pageMargins: _pageMargins,
      ),
    );
    applyReaderContentPreferences(
      fontSize: _fontSize,
      margins: _pageMargins,
      lineHeight: _lineHeight,
      wordWrap: _wordWrap,
      background: _cssColor(_backgroundColor),
      foreground: _cssColor(_textColor),
      theme: _selectedTheme,
    );
  }

  String _cssColor(Color color) {
    final value = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${value.substring(2)}';
  }

  Future<void> _increaseFont() async {
    if (_fontSize >= 180) {
      return;
    }

    setState(() {
      _fontSize += 10;
    });

    await _applyReaderStyle();
    await _saveReaderPreferences();
  }

  Future<void> _decreaseFont() async {
    if (_fontSize <= 80) {
      return;
    }

    setState(() {
      _fontSize -= 10;
    });

    await _applyReaderStyle();
    await _saveReaderPreferences();
  }

  void _increaseBrightness() {
    if (_brightness >= 1.0) {
      return;
    }

    setState(() {
      _brightness += 0.1;
    });
    _saveReaderPreferences();
  }

  void _decreaseBrightness() {
    if (_brightness <= 0.4) {
      return;
    }

    setState(() {
      _brightness -= 0.1;
    });
    _saveReaderPreferences();
  }

  Future<void> _setTheme(String theme) async {
    setState(() {
      _selectedTheme = theme;

      if (theme == 'light') {
        _backgroundColor = Colors.white;

        _textColor = Colors.black;
      }

      if (theme == 'sepia') {
        _backgroundColor = const Color(0xFFF4E7D3);

        _textColor = const Color(0xFF3E2F22);
      }

      if (theme == 'dark') {
        _backgroundColor = const Color(0xFF111111);

        _textColor = const Color(0xFFB8B8B8);
      }
    });

    await _applyReaderStyle();
    await _saveReaderPreferences();
  }

  Future<void> _changeMargins(double delta) async {
    setState(() {
      _pageMargins = (_pageMargins + delta).clamp(8, 48).toDouble();
    });
    await _applyReaderStyle();
    await _saveReaderPreferences();
  }

  Future<void> _changeLineHeight(double delta) async {
    setState(() {
      _lineHeight = (_lineHeight + delta).clamp(1.2, 2).toDouble();
    });
    await _applyReaderStyle();
    await _saveReaderPreferences();
  }

  Future<void> _setWordWrap(bool value) async {
    setState(() => _wordWrap = value);
    await _applyReaderStyle();
    await _saveReaderPreferences();
  }

  void _startMenuTimer() {
    _menuTimer?.cancel();
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });

    if (_showMenu) {
      _startMenuTimer();
    } else {
      _menuTimer?.cancel();
    }
  }

  void _openContents() {
    _menuTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return ContentsSheet(
          chapters: _tableOfContents.map((e) => e.title ?? 'Бөлүм').toList(),
          chapterPages: _tableOfContents
              .map((link) => _pageForHref(link.href))
              .toList(),

          currentIndex: _tableOfContents.indexWhere((e) {
            final tocHref = e.href.split('#').first.replaceFirst('/', '');

            final currentHref = _currentLocator?.href
                .split('#')
                .first
                .replaceFirst('/', '');

            return currentHref?.contains(tocHref) ?? false;
          }),

          onChapterTap: (index) async {
            final link = _tableOfContents[index];

            final locator = Locator(
              href: _relativeHref(link.href),
              type: 'application/xhtml+xml',
            );

            debugPrint(
              'GO TO LOCATOR → '
              '${locator.json}',
            );

            await Future.delayed(const Duration(milliseconds: 120));
            await _navigateTo(locator);
          },
        );
      },
    ).then((_) async {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      if (!mounted) {
        return;
      }

      setState(() {
        _showMenu = true;
      });

      _startMenuTimer();
    });
  }

  void _openBookmarks() async {
    _menuTimer?.cancel();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return BookmarksSheet(
          bookId: _bookId,
          onBookmarksLoaded: (bookmarks) {
            _bookmarks = bookmarks;
          },

          onBookmarkTap: (locator) async {
            final fromLocator = _currentLocator;

            final fromPage = _currentPage;

            await Future.delayed(const Duration(milliseconds: 120));

            await _navigateTo(locator);

            if (!mounted) {
              return;
            }

            final bookmarkIndex = _bookmarks.indexWhere(
              (e) => e.json == locator.json,
            );

            setState(() {
              if (!_bookmarkMode) {
                _preBookmarkLocator = fromLocator;

                _returnPage = fromPage;
              }

              _bookmarkMode = true;

              _currentBookmarkIndex = bookmarkIndex + 1;

              _showMenu = false;

              _bookmarkStartPage = locator.locations?.position ?? fromPage;
            });
          },
        );
      },
    ).then((_) {
      if (!mounted) {
        return;
      }

      if (_bookmarkMode) {
        return;
      }

      setState(() {
        _showMenu = true;
      });

      _startMenuTimer();
    });
  }

  void _openSearch() {
    if (_manifestUrl == null) return;
    _menuTimer?.cancel();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return SearchSheet(
          bookId: _bookId,
          manifestUrl: _manifestUrl!,
          publication: _publication!,

          onResultTap: (locator, query, occurrence) async {
            await _navigateTo(
              locator,
              searchQuery: query,
              searchOccurrence: occurrence,
            );
          },
        );
      },
    ).then((_) async {
      await Future.delayed(const Duration(milliseconds: 120));

      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      if (!mounted) {
        return;
      }

      setState(() {
        _showMenu = true;
      });

      _startMenuTimer();
    });
  }

  void _openSettings() {
    _menuTimer?.cancel();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return SettingsSheet(
          onDecreaseFont: _decreaseFont,

          onIncreaseFont: _increaseFont,

          onDecreaseBrightness: _decreaseBrightness,

          onIncreaseBrightness: _increaseBrightness,

          onLightTheme: () => _setTheme('light'),

          onSepiaTheme: () => _setTheme('sepia'),

          onDarkTheme: () => _setTheme('dark'),

          selectedTheme: _selectedTheme,
          fontSize: _fontSize,
          brightness: _brightness,
          pageMargins: _pageMargins,
          lineHeight: _lineHeight,
          wordWrap: _wordWrap,
          onDecreaseMargins: () => _changeMargins(-4),
          onIncreaseMargins: () => _changeMargins(4),
          onDecreaseLineHeight: () => _changeLineHeight(-.1),
          onIncreaseLineHeight: () => _changeLineHeight(.1),
          onWordWrapChanged: _setWordWrap,
        );
      },
    ).then((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _showMenu = true;
      });

      _startMenuTimer();
    });
  }

  void _handleTap(Offset position) {
    if (_bookmarkMode) {
      setState(() {
        _bookmarkMode = false;
      });

      return;
    }

    if (_showMenu) {
      _toggleMenu();
      return;
    }

    final width = MediaQuery.of(context).size.width;

    final dx = position.dx;

    if (dx < width * 0.35) {
      _flureadium.goLeft();
      return;
    }

    if (dx > width * 0.65) {
      _flureadium.goRight();
      return;
    }

    _toggleMenu();
  }

  Future<void> _navigateAfterSwipe({required bool forward}) async {
    final locatorBefore = _currentLocator?.json;
    if (forward) {
      await _flureadium.goRight();
    } else {
      await _flureadium.goLeft();
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _currentLocator?.json != locatorBefore) {
      return;
    }

    if (forward) {
      await _flureadium.goRight();
    } else {
      await _flureadium.goLeft();
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

      if (!keyboardOpen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _loadError != null
              ? _ReaderLoadError(onRetry: _openBook)
              : _publication == null
              ? _ReaderLoading(title: widget.book.title)
              : SizedBox.expand(
                  child: Stack(
                    children: [
                      IgnorePointer(
                        ignoring: _showMenu,
                        child: ReadiumReaderWidget(
                          publication: _publication!,
                          initialLocator: _initialLocator,

                          onReady: () async {
                            _subscribeToChannels();

                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );

                            await _applyReaderStyle();

                            final restore = _initialLocator;
                            if (restore != null) {
                              await _navigateTo(
                                restore,
                                rememberHistory: false,
                              );
                            }
                          },
                        ),
                      ),

                      // brightness overlay
                      IgnorePointer(
                        child: Opacity(
                          opacity: 1.0 - _brightness,
                          child: Container(color: Colors.black),
                        ),
                      ),

                      if (kIsWeb)
                        Positioned.fill(
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapUp: (details) {
                                _handleTap(details.localPosition);
                              },
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),

                      // Native platforms need explicit tap zones; the web
                      // navigator handles horizontal swipes inside its iframe.
                      if (!kIsWeb)
                        Positioned.fill(
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapUp: (details) {
                                _handleTap(details.localPosition);
                              },
                              onHorizontalDragStart: (_) {
                                _horizontalDragDelta = 0;
                                _didNavigateDrag = false;
                              },
                              onHorizontalDragUpdate: (details) {
                                _horizontalDragDelta += details.delta.dx;
                                if (_didNavigateDrag ||
                                    _horizontalDragDelta.abs() <= 40) {
                                  return;
                                }

                                _didNavigateDrag = true;
                                if (_horizontalDragDelta < 0) {
                                  unawaited(_navigateAfterSwipe(forward: true));
                                } else {
                                  unawaited(
                                    _navigateAfterSwipe(forward: false),
                                  );
                                }
                              },
                              onHorizontalDragEnd: (_) {
                                _horizontalDragDelta = 0;
                                _didNavigateDrag = false;
                              },
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),

                      ReaderMenu(
                        key: ValueKey(_currentPage),

                        showMenu: _showMenu,

                        progress: _sliderProgress,

                        currentPage: _isDraggingSlider
                            ? _previewPage
                            : _currentPage,
                        totalPages: _totalPages,
                        canGoBack: _backHistory.isNotEmpty,
                        canGoForward: _forwardHistory.isNotEmpty,
                        onBackTap: () => unawaited(_goBackInReader()),
                        onForwardTap: () => unawaited(_goForwardInReader()),

                        onProgressChanged: (value) {
                          _menuTimer?.cancel();

                          setState(() {
                            _isDraggingSlider = true;

                            _sliderProgress = value;

                            _previewPage = _totalPages <= 1
                                ? 1
                                : (value * (_totalPages - 1)).round() + 1;
                          });
                        },
                        isBookmarked: _isBookmarked,

                        onBookmarkToggle: () async {
                          await _addBookmark();
                        },

                        onProgressChangeEnd: (value) async {
                          final targetPosition = _totalPages <= 1
                              ? 1
                              : (value * (_totalPages - 1)).round() + 1;

                          debugPrint(
                            'TARGET POSITION → '
                            '$targetPosition',
                          );

                          if (_pageLocators.isNotEmpty) {
                            await _navigateTo(
                              _pageLocators[targetPosition - 1],
                            );
                          }

                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            _isDraggingSlider = false;

                            _previewPage = _currentPage;
                          });

                          _startMenuTimer();
                        },

                        onSettingsTap: _openSettings,

                        onContentsTap: _openContents,

                        onSearchTap: _openSearch,

                        onBookmarkTap: _openBookmarks,
                      ),

                      if (_showMenu)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          left: 18,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F2EC),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Color(0xFF4A4035),
                                    size: 16,
                                  ),

                                  SizedBox(width: 6),

                                  Text(
                                    'Чыгуу',
                                    style: TextStyle(
                                      color: Color(0xFF4A4035),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      if (_isBookmarked)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 0,
                          right: 10,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.45,
                              child: const Icon(
                                Icons.bookmark,
                                color: Color(0xFF5E9F73),
                                size: 60,
                              ),
                            ),
                          ),
                        ),

                      if (_bookmarkMode)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 70,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F2EC),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),

                                Center(
                                  child: Container(
                                    width: 42,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFD7CABB),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 0),

                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,

                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,

                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: GestureDetector(
                                            onTap: () async {
                                              if (_preBookmarkLocator == null) {
                                                return;
                                              }

                                              await _flureadium.goToLocator(
                                                _relativeLocator(
                                                  _preBookmarkLocator!,
                                                ),
                                              );

                                              if (!mounted) {
                                                return;
                                              }

                                              setState(() {
                                                _bookmarkMode = false;

                                                _preBookmarkLocator = null;

                                                _returnPage = null;
                                              });
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.arrow_back,
                                                  color: Color(0xFFA07A3F),
                                                  size: 20,
                                                ),

                                                const SizedBox(width: 2),

                                                Text(
                                                  '$_returnPage-бетке',
                                                  style: const TextStyle(
                                                    color: Color(0xFFA07A3F),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      Transform.translate(
                                        offset: const Offset(0, 0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(width: 12),

                                            IconButton(
                                              onPressed:
                                                  _currentBookmarkIndex > 1
                                                  ? () async {
                                                      final newIndex =
                                                          _currentBookmarkIndex -
                                                          2;

                                                      final locator =
                                                          _bookmarks[newIndex];

                                                      _isBookmarkNavigation =
                                                          true;

                                                      await _flureadium
                                                          .goToLocator(
                                                            _relativeLocator(
                                                              locator,
                                                            ),
                                                          );

                                                      if (!mounted) {
                                                        return;
                                                      }

                                                      setState(() {
                                                        _currentBookmarkIndex--;
                                                      });
                                                    }
                                                  : null,
                                              icon: const Icon(
                                                Icons.chevron_left,
                                                size: 24,
                                              ),
                                            ),

                                            Text(
                                              '$_currentBookmarkIndex / ${_bookmarks.length}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),

                                            IconButton(
                                              onPressed:
                                                  _currentBookmarkIndex <
                                                      _bookmarks.length
                                                  ? () async {
                                                      final newIndex =
                                                          _currentBookmarkIndex;

                                                      final locator =
                                                          _bookmarks[newIndex];

                                                      _isBookmarkNavigation =
                                                          true;

                                                      await _flureadium
                                                          .goToLocator(
                                                            _relativeLocator(
                                                              locator,
                                                            ),
                                                          );

                                                      if (!mounted) {
                                                        return;
                                                      }

                                                      setState(() {
                                                        _currentBookmarkIndex++;
                                                      });
                                                    }
                                                  : null,
                                              icon: const Icon(
                                                Icons.chevron_right,
                                                size: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: _openBookmarks,
                                            icon: const Icon(
                                              Icons.bookmarks_outlined,
                                              size: 24,
                                            ),
                                          ),

                                          const SizedBox(width: 0),

                                          Transform.translate(
                                            offset: const Offset(5, -35),
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,

                                              onTap: () {
                                                setState(() {
                                                  _bookmarkMode = false;

                                                  _preBookmarkLocator = null;

                                                  _returnPage = null;

                                                  _currentBookmarkIndex = 0;
                                                });
                                              },

                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFE7DCCF,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.close_rounded,
                                                      size: 20,
                                                      weight: 900,
                                                      color: Color(0xFFD15D52),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readingTimer?.cancel();
    unawaited(_syncReadingProgress());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _menuTimer?.cancel();

    unregisterReaderSwipeBridge();

    super.dispose();
  }
}

class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4E7D3),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B6B35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF3E2F22),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF0B6B35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderLoadError extends StatelessWidget {
  const _ReaderLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4E7D3),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 52,
                  color: Color(0xFF0B6B35),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Китеп ачылган жок',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Файлды кайра жүктөп көрүңүз.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6E6258)),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Кайра аракет кылуу'),
                ),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Артка кайтуу'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
