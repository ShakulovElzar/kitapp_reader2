import 'package:flutter/material.dart';

/// Dark navy colors shared by the reader's panel, chapter list, bookmarks and search.
abstract final class ReaderPalette {
  static const panelTop = Color(0xFF221F42);
  static const panelBottom = Color(0xFF0C0B1F);
  static const card = Color(0xFF2A2752);
  static const divider = Color(0xFF3B3870);
  static const accent = Color(0xFF7D86F0);
  static const accentStrong = Color(0xFF3138C9);
  static const text = Colors.white;
  static const muted = Color(0xFFA6A4C7);
  static const bookmark = Color(0xFFF0476B);
  static const backButton = Color(0xFF6E6A9E);

  static const panelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [panelTop, panelBottom],
  );

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: accent,
        onPrimary: Colors.white,
        surface: panelTop,
        onSurface: text,
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      iconTheme: const IconThemeData(color: text),
      listTileTheme: const ListTileThemeData(textColor: text, iconColor: muted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: card),
      dialogTheme: const DialogThemeData(backgroundColor: panelTop),
    );
  }
}

/// Reader page themes: background and text colors.
class ReaderTheme {
  const ReaderTheme(this.id, this.background, this.text);

  final String id;
  final Color background;
  final Color text;

  static const all = [
    ReaderTheme('light', Colors.white, Color(0xFF1B1B1B)),
    ReaderTheme('sepia', Color(0xFFF4E7D3), Color(0xFF3E2F22)),
    ReaderTheme('gray', Color(0xFF2C2C2E), Color(0xFFD6D6D6)),
    ReaderTheme('dark', Color(0xFF000000), Color(0xFFB8B8B8)),
  ];

  static ReaderTheme byId(String id) =>
      all.firstWhere((theme) => theme.id == id, orElse: () => all[1]);
}

/// Fonts offered in reader settings (web-safe families).
const readerFonts = <String>['Georgia', 'Times New Roman', 'Arial', 'Verdana'];
