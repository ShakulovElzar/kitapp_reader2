import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flureadium/flureadium.dart';
import 'package:http/http.dart' as http;

import '../models/book.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/reader_palette.dart';
import '../widgets/reader_panel.dart';
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
  bool _syncing = false;
  bool _isActive = true;

  int _fontSize = 120;

  double _pageMargins = 20;

  double _lineHeight = 1.5;

  bool _wordWrap = true;

  double _brightness = 1.0;

  String _fontFamily = readerFonts.first;

  ReaderPanelTab _panelTab = ReaderPanelTab.contents;

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

  String get _locatorKey => _api!.userKey('locator_$_bookId');

  String get _locatorTimeKey => _api!.userKey('locator_at_$_bookId');

  String get _pageKey => _api!.userKey('reader_page_$_bookId');

  String get _bookmarksKey => _api!.userKey('bookmarks_$_bookId');

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
    final theme = ReaderTheme.byId(prefs.getString('reader_theme') ?? 'sepia');
    _fontSize = (prefs.getInt('reader_font_size') ?? 120).clamp(80, 200);
    _brightness = (prefs.getDouble('reader_brightness') ?? 1.0).clamp(0.3, 1.0);
    _pageMargins = (prefs.getDouble('reader_page_margins') ?? 20).clamp(0, 48);
    _lineHeight = (prefs.getDouble('reader_line_height') ?? 1.5).clamp(
      1.0,
      2.2,
    );
    _wordWrap = prefs.getBool('reader_word_wrap') ?? true;
    final font = prefs.getString('reader_font_family');
    _fontFamily = readerFonts.contains(font) ? font! : readerFonts.first;
    _selectedTheme = theme.id;
    _backgroundColor = theme.background;
    _textColor = theme.text;
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
      prefs.setString('reader_font_family', _fontFamily),
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
        final serverPosition = await _loadServerPosition();
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
          _pageLocators = pageLocators;
          _totalPages = pageLocators.isEmpty ? 1 : pageLocators.length;
          // Resume from the server when it has a newer position (another device).
          final startPage = serverPosition != null
              ? _pageForLocator(_relativeLocator(serverPosition))
              : savedPage ??
                    (savedLocator == null
                        ? null
                        : _pageForLocator(_relativeLocator(savedLocator)));
          _initialLocator = startPage == null || pageLocators.isEmpty
              ? null
              : _positionLocator(
                  pageLocators[(startPage - 1).clamp(
                    0,
                    pageLocators.length - 1,
                  )],
                );
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

      // Native apps are out of scope for the MVP; never open a placeholder book.
      throw const _UnsupportedPlatform();
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
    final locator = _currentLocator;
    if (_syncing ||
        _unsyncedActiveSeconds == 0 ||
        locator == null ||
        _api == null) {
      return;
    }
    _syncing = true;
    // The server accepts at most 300 seconds per request; the rest waits for the next sync.
    final seconds = _unsyncedActiveSeconds.clamp(1, 300);
    _unsyncedActiveSeconds -= seconds;
    try {
      await _api!.saveProgress(
        bookId: _bookId,
        progression: locator.locations?.totalProgression ?? _sliderProgress,
        activeSeconds: seconds,
        locator: jsonDecode(locator.json) as Map<String, dynamic>,
      );
    } catch (_) {
      _unsyncedActiveSeconds += seconds;
    } finally {
      _syncing = false;
    }
  }

  /// The server's position for this book if it is newer than this device's.
  Future<Locator?> _loadServerPosition() async {
    try {
      final remote = await _api!.readingPosition(_bookId);
      if (remote == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final localAt = DateTime.tryParse(prefs.getString(_locatorTimeKey) ?? '');
      if (localAt != null && !remote.lastReadAt.isAfter(localAt)) return null;
      return Locator.fromJson(remote.locator);
    } catch (_) {
      return null;
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

  /// The paginated web navigator only opens at an exact entry of positions.json,
  /// whose hrefs carry no #fragment.
  Locator _positionLocator(Locator page) {
    final value = jsonDecode(page.json) as Map<String, dynamic>;
    value['href'] = (value['href'] as String).split('#').first;
    return Locator.fromJson(value)!;
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
    // positions.json mirrors the page list, so the navigator's position is the page.
    final navigatorPosition = locator.locations?.position;
    if (_pageLocators.isNotEmpty &&
        navigatorPosition != null &&
        navigatorPosition >= 1 &&
        navigatorPosition <= _pageLocators.length) {
      return navigatorPosition;
    }
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

      final rawTitles = prefs.getString(
        _api!.userKey('bookmark_titles_$_bookId'),
      );
      if (rawTitles != null) {
        final titles = Map<String, dynamic>.from(jsonDecode(rawTitles) as Map);
        titles.remove(locatorJson);
        await prefs.setString(
          _api!.userKey('bookmark_titles_$_bookId'),
          jsonEncode(titles),
        );
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
      await prefs.setString(
        _locatorTimeKey,
        DateTime.now().toUtc().toIso8601String(),
      );
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
        fontFamily: _fontFamily,

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
      fontFamily: _fontFamily,
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

  /// Applies reader settings to the page and saves them.
  Future<void> _commitReaderStyle() async {
    await _applyReaderStyle();
    await _saveReaderPreferences();
  }

  Future<void> _setTheme(String id) async {
    final theme = ReaderTheme.byId(id);
    setState(() {
      _selectedTheme = theme.id;
      _backgroundColor = theme.background;
      _textColor = theme.text;
    });
    await _commitReaderStyle();
  }

  Future<void> _setFontFamily(String value) async {
    setState(() => _fontFamily = value);
    await _commitReaderStyle();
  }

  Future<void> _setWordWrap(bool value) async {
    setState(() => _wordWrap = value);
    await _commitReaderStyle();
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
    final chapterPages = _tableOfContents
        .map((link) => _pageForHref(link.href))
        .toList();
    // The current chapter is the last one starting at or before this page.
    var currentChapter = -1;
    for (var i = 0; i < chapterPages.length; i++) {
      if (chapterPages[i] <= _currentPage) currentChapter = i;
    }
    _menuTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return ContentsSheet(
          bookTitle: widget.book.title,
          chapters: _tableOfContents.map((e) => e.title ?? 'Бөлүм').toList(),
          chapterPages: chapterPages,
          currentIndex: currentChapter,

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
      backgroundColor: _backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _loadError != null
              ? _ReaderLoadError(
                  onRetry: _openBook,
                  unsupported: _loadError is _UnsupportedPlatform,
                )
              : _publication == null
              ? _ReaderLoading(title: widget.book.title)
              : SizedBox.expand(
                  child: Stack(
                    children: [
                      IgnorePointer(
                        ignoring: _showMenu,
                        child: Padding(
                          // Keep text clear of the top buttons and page counter.
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 44,
                            bottom: MediaQuery.of(context).padding.bottom + 40,
                          ),
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

                      if (!_showMenu && !_bookmarkMode)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: MediaQuery.of(context).padding.bottom + 12,
                          child: IgnorePointer(
                            child: Text(
                              '$_currentPage / $_totalPages',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textColor.withValues(alpha: .55),
                                fontSize: 12,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),

                      if (_isBookmarked && !_showMenu)
                        Positioned(
                          top: 0,
                          right: 22,
                          child: IgnorePointer(
                            child: Icon(
                              Icons.bookmark_rounded,
                              color: ReaderPalette.bookmark.withValues(
                                alpha: .85,
                              ),
                              size: 34,
                            ),
                          ),
                        ),

                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ReaderTopButtons(
                          visible: _showMenu,
                          isBookmarked: _isBookmarked,
                          onBack: () => Navigator.pop(context),
                          onBookmarkToggle: () => unawaited(_addBookmark()),
                        ),
                      ),

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ReaderPanel(
                          visible: _showMenu,
                          tab: _panelTab,
                          onTabChanged: (tab) =>
                              setState(() => _panelTab = tab),
                          onClose: () => setState(() => _showMenu = false),
                          title: widget.book.title,
                          author: widget.book.author,
                          progress: _sliderProgress,
                          currentPage: _isDraggingSlider
                              ? _previewPage
                              : _currentPage,
                          totalPages: _totalPages,
                          onProgressChanged: (value) {
                            setState(() {
                              _isDraggingSlider = true;
                              _sliderProgress = value;
                              _previewPage = _totalPages <= 1
                                  ? 1
                                  : (value * (_totalPages - 1)).round() + 1;
                            });
                          },
                          onProgressChangeEnd: (value) async {
                            final target = _totalPages <= 1
                                ? 1
                                : (value * (_totalPages - 1)).round() + 1;
                            if (_pageLocators.isNotEmpty) {
                              await _navigateTo(_pageLocators[target - 1]);
                            }
                            if (!mounted) return;
                            setState(() {
                              _isDraggingSlider = false;
                              _previewPage = _currentPage;
                            });
                          },
                          canGoBack: _backHistory.isNotEmpty,
                          canGoForward: _forwardHistory.isNotEmpty,
                          onBackTap: () => unawaited(_goBackInReader()),
                          onForwardTap: () => unawaited(_goForwardInReader()),
                          onChaptersTap: _openContents,
                          onBookmarksTap: _openBookmarks,
                          onSearchTap: _openSearch,
                          selectedTheme: _selectedTheme,
                          onThemeSelected: (id) => unawaited(_setTheme(id)),
                          fontFamily: _fontFamily,
                          onFontChanged: (font) =>
                              unawaited(_setFontFamily(font)),
                          fontSize: _fontSize,
                          onFontSizeChanged: (value) =>
                              setState(() => _fontSize = value.clamp(80, 200)),
                          margins: _pageMargins,
                          onMarginsChanged: (value) =>
                              setState(() => _pageMargins = value),
                          lineHeight: _lineHeight,
                          onLineHeightChanged: (value) =>
                              setState(() => _lineHeight = value),
                          brightness: _brightness,
                          onBrightnessChanged: (value) =>
                              setState(() => _brightness = value),
                          hyphenate: _wordWrap,
                          onHyphenateChanged: (value) =>
                              unawaited(_setWordWrap(value)),
                          onSettingsChangeEnd: () =>
                              unawaited(_commitReaderStyle()),
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
                              gradient: ReaderPalette.panelGradient,
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
                                      color: ReaderPalette.divider,
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
                                                  color: ReaderPalette.accent,
                                                  size: 20,
                                                ),

                                                const SizedBox(width: 2),

                                                Text(
                                                  '$_returnPage-бетке',
                                                  style: const TextStyle(
                                                    color: ReaderPalette.accent,
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
                                                color: Colors.white,
                                              ),
                                            ),

                                            Text(
                                              '$_currentBookmarkIndex / ${_bookmarks.length}',
                                              style: const TextStyle(
                                                color: Colors.white,
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
                                                color: Colors.white,
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
                                              color: ReaderPalette.bookmark,
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
                                                        color:
                                                            ReaderPalette.card,
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

class _UnsupportedPlatform implements Exception {
  const _UnsupportedPlatform();
}

class _ReaderLoadError extends StatelessWidget {
  const _ReaderLoadError({required this.onRetry, this.unsupported = false});

  final VoidCallback onRetry;
  final bool unsupported;

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
                Text(
                  unsupported
                      ? 'Азырынча китептерди веб-версияда гана окууга болот.'
                      : 'Файлды кайра жүктөп көрүңүз.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6E6258)),
                ),
                const SizedBox(height: 18),
                if (!unsupported)
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
