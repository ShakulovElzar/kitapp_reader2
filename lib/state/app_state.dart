import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';

class AppStateController extends ChangeNotifier {
  AppStateController._(this._prefs);

  final SharedPreferences _prefs;
  final Set<String> _purchased = {};
  final Map<String, DateTime> _rentals = {};
  final Map<String, double> _progress = {};
  bool _showAdult = false;

  static Future<AppStateController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppStateController._(prefs);
    state._purchased.addAll(prefs.getStringList('purchased_books') ?? []);
    state._showAdult = prefs.getBool('show_adult') ?? false;

    for (final book in demoBooks) {
      final rental = prefs.getString('rental_${book.id}');
      final progress = prefs.getDouble('progress_${book.id}');
      if (rental != null) {
        final date = DateTime.tryParse(rental);
        if (date != null) state._rentals[book.id] = date;
      }
      if (progress != null) state._progress[book.id] = progress;
    }
    return state;
  }

  bool get showAdult => _showAdult;

  List<Book> get visibleBooks => demoBooks
      .where((book) => _showAdult || !book.isAdult)
      .toList(growable: false);

  List<Book> get libraryBooks =>
      demoBooks.where((book) => hasAccess(book)).toList(growable: false);

  bool isPurchased(Book book) => _purchased.contains(book.id);

  DateTime? rentalEnd(Book book) => _rentals[book.id];

  bool isRented(Book book) {
    final end = rentalEnd(book);
    return end != null && end.isAfter(DateTime.now());
  }

  bool hasAccess(Book book) =>
      book.isFree || isPurchased(book) || isRented(book);

  double progressFor(Book book) => _progress[book.id] ?? 0;

  Future<void> buy(Book book) async {
    _purchased.add(book.id);
    _rentals.remove(book.id);
    await _prefs.setStringList('purchased_books', _purchased.toList());
    await _prefs.remove('rental_${book.id}');
    notifyListeners();
  }

  Future<void> rent(Book book) async {
    final end = DateTime.now().add(const Duration(days: 7));
    _rentals[book.id] = end;
    await _prefs.setString('rental_${book.id}', end.toIso8601String());
    notifyListeners();
  }

  Future<void> addFree(Book book) => buy(book);

  Future<void> removeFromLibrary(Book book) async {
    _purchased.remove(book.id);
    _rentals.remove(book.id);
    _progress.remove(book.id);
    await _prefs.setStringList('purchased_books', _purchased.toList());
    await _prefs.remove('rental_${book.id}');
    await _prefs.remove('progress_${book.id}');
    notifyListeners();
  }

  Future<void> setProgress(Book book, double value) async {
    final progress = value.clamp(0.0, 1.0);
    _progress[book.id] = progress;
    await _prefs.setDouble('progress_${book.id}', progress);
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

  static AppStateController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing');
    return scope!.notifier!;
  }
}
