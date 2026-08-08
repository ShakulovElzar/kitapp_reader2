import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flureadium/flureadium.dart';

import '../models/book.dart';
import '../widgets/reader_menu.dart';
import '../widgets/settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/reader_swipe_bridge.dart';
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

class _ReaderScreenState extends State<ReaderScreen> {
  final Flureadium _flureadium = Flureadium();

  Publication? _publication;

  Object? _loadError;

  int _fontSize = 120;

  double _brightness = 1.0;

  double _sliderProgress = 0.0;

  bool _isDraggingSlider = false;

  Locator? _currentLocator;

  int _currentPage = 1;

  int _totalPages = 1;

  int _previewPage = 1;

  String get _bookId => widget.book.id;

  String get _locatorKey => 'locator_$_bookId';

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

    registerReaderSwipeBridge(
      onForward: () => unawaited(_flureadium.goRight()),
      onBackward: () => unawaited(_flureadium.goLeft()),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadReaderPreferences();
      _openBook();
    });
  }

  Future<void> _loadReaderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('reader_theme') ?? 'sepia';
    _fontSize = prefs.getInt('reader_font_size') ?? 120;
    _brightness = prefs.getDouble('reader_brightness') ?? 1.0;
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
      const assetPath = 'assets/books/test.epub';

      if (kIsWeb) {
        final manifest =
            jsonDecode(
                  await rootBundle.loadString('web/books/test/manifest.json'),
                )
                as Map<String, dynamic>;

        final links = manifest['links'] as List<dynamic>;

        final manifestUrl = Uri.base
            .resolve('books/test/manifest.json')
            .toString();

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
          _tableOfContents = publication.tableOfContents;
        });

        return;
      }

      final bytes = await rootBundle.load(assetPath);

      final tempFile = File('${Directory.systemTemp.path}/test.epub');

      await tempFile.writeAsBytes(bytes.buffer.asUint8List());

      final publication = await _flureadium.openPublication(tempFile.path);

      debugPrint(publication.toString());

      debugPrint(publication.toString());

      if (!mounted) {
        return;
      }

      setState(() {
        _publication = publication;

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

  void _subscribeToChannels() {
    _flureadium.onTextLocatorChanged.listen((locator) {
      debugPrint(
        'FRAGMENTS: '
        '${locator.locations?.fragments}',
      );

      final progress = locator.locations?.totalProgression ?? 0.0;

      if (!mounted) {
        return;
      }

      _saveLocator(locator);
      widget.onProgress?.call(progress);

      final position = locator.locations?.position;

      debugPrint(locator.json);

      final progression = locator.locations?.totalProgression ?? 0.0;

      setState(() {
        _currentLocator = locator;

        _currentPage = position ?? 1;

        if (progression > 0) {
          _totalPages = (_currentPage / progression).round();
        }

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

    final locatorJson = _currentLocator!.json;

    final exists = bookmarks.contains(locatorJson);

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

    final locatorJson = _currentLocator!.json;

    final exists = bookmarks.contains(locatorJson);

    if (exists) {
      final index = bookmarks.indexOf(locatorJson);

      bookmarks.remove(locatorJson);

      await prefs.setStringList(_bookmarksKey, bookmarks);

      final titles = prefs.getStringList('bookmark_titles_$_bookId') ?? [];

      if (index >= 0 && index < titles.length) {
        await prefs.setStringList('bookmark_titles_$_bookId', titles);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isBookmarked = false;
      });

      return;
    }

    bookmarks.add(locatorJson);

    await prefs.setStringList(_bookmarksKey, bookmarks);

    if (!mounted) {
      return;
    }

    setState(() {
      _isBookmarked = true;
    });
  }

  Future<void> _saveLocator(Locator locator) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_locatorKey, locator.json);

      debugPrint('LOCATOR SAVED');
    } catch (e) {
      debugPrint('SAVE LOCATOR ERROR: $e');
    }
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
      ),
    );
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
    if (_fontSize <= 90) {
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
    if (_brightness <= 0.3) {
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

  void _startMenuTimer() {
    _menuTimer?.cancel();

    _menuTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showMenu = false;
      });
    });
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
              href: link.href,
              type: 'application/xhtml+xml',
            );

            debugPrint(
              'GO TO LOCATOR → '
              '${locator.json}',
            );

            await Future.delayed(const Duration(milliseconds: 120));

            await _flureadium.goToLocator(locator);

            await Future.delayed(const Duration(milliseconds: 180));

            await _flureadium.goToLocator(locator);
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
          onBookmarksLoaded: (bookmarks) {
            _bookmarks = bookmarks;
          },

          onBookmarkTap: (locator) async {
            final fromLocator = _currentLocator;

            final fromPage = _currentPage;

            await Future.delayed(const Duration(milliseconds: 120));

            await _flureadium.goToLocator(locator);

            await Future.delayed(const Duration(milliseconds: 180));

            await _flureadium.goToLocator(locator);

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
    _menuTimer?.cancel();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return SearchSheet(
          publication: _publication!,

          onBookmarkTap: (locator) async {
            await _flureadium.goToLocator(locator);
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

                          onReady: () async {
                            _subscribeToChannels();

                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );

                            await _applyReaderStyle();

                            final savedLocator = kIsWeb
                                ? null
                                : await _loadSavedLocator();

                            if (savedLocator != null) {
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );

                              await _flureadium.goToLocator(savedLocator);

                              debugPrint('LOCATOR RESTORED');
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

                        onProgressChanged: (value) {
                          _menuTimer?.cancel();

                          setState(() {
                            _isDraggingSlider = true;

                            _sliderProgress = value;

                            _previewPage = (value * _totalPages).round().clamp(
                              1,
                              _totalPages,
                            );
                          });
                        },
                        isBookmarked: _isBookmarked,

                        onBookmarkToggle: () async {
                          await _addBookmark();
                        },

                        onProgressChangeEnd: (value) async {
                          final targetPosition = (value * _totalPages)
                              .round()
                              .clamp(1, _totalPages);

                          final newLocator = Locator(
                            href: '',

                            type: 'application/xhtml+xml',

                            locations: Locations(position: targetPosition),
                          );

                          debugPrint(
                            'TARGET POSITION → '
                            '$targetPosition',
                          );

                          debugPrint(newLocator.json);

                          await _flureadium.goToLocator(newLocator);

                          await Future.delayed(
                            const Duration(milliseconds: 180),
                          );

                          await _flureadium.goToLocator(newLocator);

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
                                                _preBookmarkLocator!,
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
                                                          .goToLocator(locator);

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
                                                          .goToLocator(locator);

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
