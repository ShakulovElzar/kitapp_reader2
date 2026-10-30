import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._prefs);

  static const baseUrl = String.fromEnvironment(
    'KITAPP_API_URL',
    defaultValue: 'http://127.0.0.1:3000/api',
  );

  final SharedPreferences _prefs;

  /// Called after the server rejects the saved token (expired or revoked).
  void Function()? onUnauthorized;

  String? get token => _prefs.getString('reader_token');
  String? get phone => _prefs.getString('reader_phone');

  /// Returns the code only when the server runs in local development mode.
  Future<String?> requestOtp(String phone) async {
    final value = await _request(
      '/auth/phone/request-otp',
      method: 'POST',
      body: {'phone': phone},
    );
    return (value as Map<String, dynamic>?)?['developmentCode'] as String?;
  }

  Future<void> verifyOtp(String phone, String code) async {
    final value =
        await _request(
              '/auth/phone/verify-otp',
              method: 'POST',
              body: {'phone': phone, 'code': code},
            )
            as Map<String, dynamic>;
    await Future.wait([
      _prefs.setString('reader_token', value['token'] as String),
      _prefs.setString('reader_phone', phone),
    ]);
  }

  Future<void> logout() async {
    await Future.wait([
      _prefs.remove('reader_token'),
      _prefs.remove('reader_phone'),
    ]);
  }

  Future<List<Book>> catalog() async {
    final value = await _request('/catalog/books') as List<dynamic>;
    return value
        .map((item) => Book.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Book>> library() async {
    final value =
        await _request('/reader/library', authenticated: true) as List<dynamic>;
    return value
        .map((item) => Book.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<RecentBook>> recent() async {
    final value =
        await _request('/reader/recent', authenticated: true) as List<dynamic>;
    return value.map((item) {
      final json = item as Map<String, dynamic>;
      return RecentBook(
        book: Book.fromJson(json['book'] as Map<String, dynamic>),
        progression: (json['progression'] as num?)?.toDouble() ?? 0,
        locator: json['locator'] as Map<String, dynamic>?,
      );
    }).toList();
  }

  Future<void> buy(String bookId) => _request(
    '/reader/purchases',
    method: 'POST',
    authenticated: true,
    body: {'bookId': bookId},
  );

  Future<void> rent(String bookId) => _request(
    '/reader/rentals',
    method: 'POST',
    authenticated: true,
    body: {'bookId': bookId},
  );

  Future<String> bookManifest(String bookId) async {
    final value =
        await _request('/reader/books/$bookId/file', authenticated: true)
            as Map<String, dynamic>;
    return value['manifestUrl'] as String;
  }

  Future<void> saveProgress({
    required String bookId,
    required double progression,
    required int activeSeconds,
    Map<String, dynamic>? locator,
  }) => _request(
    '/reader/progress',
    method: 'POST',
    authenticated: true,
    body: {
      'bookId': bookId,
      'progression': progression.clamp(0, 1),
      'activeSeconds': activeSeconds.clamp(1, 300),
      'locator': ?locator,
    },
  );

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    bool authenticated = false,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final value = token;
      if (value == null) throw const ApiException('Кайра кириңиз');
      headers['Authorization'] = 'Bearer $value';
    }
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = switch (method) {
        'POST' => await http.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        _ => await http.get(uri, headers: headers),
      };
    } catch (_) {
      throw const ApiException('Серверге туташуу мүмкүн болгон жок');
    }
    if (authenticated && response.statusCode == 401) {
      await logout();
      onUnauthorized?.call();
      throw const ApiException('Сессия бүттү. Кайра кириңиз');
    }
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']
          : null;
      throw ApiException(
        message is List
            ? message.join(', ')
            : message?.toString() ?? 'Ката кетти',
      );
    }
    return decoded;
  }
}

class RecentBook {
  const RecentBook({
    required this.book,
    required this.progression,
    this.locator,
  });

  final Book book;
  final double progression;
  final Map<String, dynamic>? locator;
}
