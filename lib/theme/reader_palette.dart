import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Colors of the reader's panel and sheets. They use the app's own tokens
/// (design A), so the reader no longer looks like a separate app.
abstract final class ReaderPalette {
  static const panelTop = Colors.white;
  static const panelBottom = Colors.white;
  static const card = AppColors.paper;
  static const divider = AppColors.line;
  static const accent = AppColors.green;
  static const accentStrong = AppColors.green;
  static const text = AppColors.ink;
  static const muted = AppColors.muted;
  static const bookmark = AppColors.green;
  static const backButton = Colors.white;

  /// Kept as a gradient type for existing call sites; it is a flat white.
  static const panelGradient = LinearGradient(colors: [panelTop, panelBottom]);

  static ThemeData theme(BuildContext context) => Theme.of(context);
}

/// Reader page themes: background and text colors.
class ReaderTheme {
  const ReaderTheme(this.id, this.name, this.background, this.text);

  final String id;
  final String name;
  final Color background;
  final Color text;

  static const all = [
    ReaderTheme('light', 'Ак', Color(0xFFFAFAF7), Color(0xFF232623)),
    ReaderTheme('sepia', 'Сепия', Color(0xFFF3E8D6), Color(0xFF3D3022)),
    ReaderTheme('gray', 'Боз', Color(0xFF3A3C3F), Color(0xFFE2E1DC)),
    ReaderTheme('dark', 'Түн', Color(0xFF16171A), Color(0xFFC9C6BE)),
  ];

  static ReaderTheme byId(String id) =>
      all.firstWhere((theme) => theme.id == id, orElse: () => all.first);
}

/// Fonts offered for the book text. The book page loads them from Google
/// Fonts (see web/index.html); the app bundles them for the preview.
const readerFonts = <String>['Literata', 'PT Serif', 'Golos Text'];
