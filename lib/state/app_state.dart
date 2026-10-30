import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';
import '../services/api_client.dart';

class AppStateController extends ChangeNotifier {
  AppStateController._(this._prefs, this.api) {
    api.onUnauthorized = _clearSession;
  }

  final SharedPreferences _prefs;
  final ApiClient api;
  final Map<String, double> _progress = {};
  final Map<String, DateTime> _rentalEnds = {};
  final Set<String> _libraryIds = {};
  final Set<String> _purchasedIds = {};
  List<Book> _books = const [];
  List<Book> _library = const [];
  List<RecentBook> _recent = const [];
  bool _showAdult = false;
  bool _loading = false;
  String? _error;

  static Future<AppStateController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppStateController._(prefs, ApiClient(prefs));
    state._showAdult = prefs.getBool('show_adult') ?? false;
    state._loadLocalProgress();
    if (state.isAuthenticated) await state.refresh();
    return state;
  }

  void _loadLocalProgress() {
    _progress.clear();
    final prefix = api.userKey('progress_');
    for (final key in _prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final value = _prefs.getDouble(key);
      if (value != null) _progress[key.substring(prefix.length)] = value;
    }
  }

  bool get isAuthenticated => api.token != null;
  String get phone => api.phone ?? '';
  bool get loading => _loading;
  String? get error => _error;
  bool get showAdult => _showAdult;
  List<RecentBook> get recent => _recent;

  List<Book> get visibleBooks => _books
      .where((book) => _showAdult || !book.isAdult)
      .toList(growable: false);
  List<Book> get libraryBooks => _library
      .where((book) => _showAdult || !book.isAdult)
      .toList(growable: false);

  bool isPurchased(Book book) => _purchasedIds.contains(book.id);
  bool inLibrary(Book book) => _libraryIds.contains(book.id);
  int get purchasedCount => _purchasedIds.length;
  DateTime? rentalEnd(Book book) => _rentalEnds[book.id];
  bool isRented(Book book) => rentalEnd(book)?.isAfter(DateTime.now()) ?? false;
  bool hasAccess(Book book) => book.isFree || _libraryIds.contains(book.id);
  double progressFor(Book book) => _progress[book.id] ?? 0;

  Future<String?> requestOtp(String phone) => api.requestOtp(phone);

  Future<void> verifyOtp(String phone, String code) async {
    await api.verifyOtp(phone, code);
    _loadLocalProgress();
    await refresh();
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    _clearSession();
  }

  void _clearSession() {
    _books = const [];
    _library = const [];
    _recent = const [];
    _libraryIds.clear();
    _purchasedIds.clear();
    _rentalEnds.clear();
    _progress.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        api.catalog(),
        api.library(),
        api.recent(),
      ]);
      _books = results[0] as List<Book>;
      _library = results[1] as List<Book>;
      _recent = results[2] as List<RecentBook>;
      _libraryIds
        ..clear()
        ..addAll(_library.map((book) => book.id));
      _purchasedIds
        ..clear()
        ..addAll(
          _library
              .where((book) => book.readerAccess == 'PURCHASE')
              .map((book) => book.id),
        );
      _rentalEnds
        ..clear()
        ..addEntries(
          _library
              .where((book) => book.rentalEndsAt != null)
              .map((book) => MapEntry(book.id, book.rentalEndsAt!)),
        );
      for (final item in _recent) {
        _progress[item.book.id] = item.progression;
      }
    } on ApiException catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Маалымат жүктөлгөн жок';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> buy(Book book) async {
    await api.buy(book.id);
    await refresh();
  }

  Future<void> rent(Book book) async {
    await api.rent(book.id);
    await refresh();
  }

  Future<void> addFree(Book book) => buy(book);

  Future<void> setProgress(Book book, double value) async {
    final progress = value.clamp(0.0, 1.0);
    _progress[book.id] = progress;
    await _prefs.setDouble(api.userKey('progress_${book.id}'), progress);
    notifyListeners();
  }

  Future<void> setShowAdult(bool value) async {
    _showAdult = value;
    await _prefs.setBool('show_adult', value);
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppStateController> {
  const AppStateScope({
    super.key,
    required AppStateController state,
    required super.child,
  }) : super(notifier: state);

  /// Reads the controller without subscribing to changes (safe in initState).
  static AppStateController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing');
    return scope!.notifier!;
  }

  static AppStateController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing');
    return scope!.notifier!;
  }
}
