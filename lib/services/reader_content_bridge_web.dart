import 'dart:convert';
import 'dart:js_interop';

@JS('kitappApplyReaderPreferences')
external void _applyReaderPreferences(JSString preferences);

@JS('kitappGoToReaderFragment')
external void _goToReaderFragment(JSString fragment);

@JS('kitappHighlightReaderSearch')
external void _highlightReaderSearch(JSString query, JSNumber occurrence);

@JS('kitappClearReaderSearch')
external void _clearReaderSearch();

void applyReaderContentPreferences({
  required int fontSize,
  required String fontFamily,
  required double margins,
  required double lineHeight,
  required bool wordWrap,
  required String background,
  required String foreground,
  required String theme,
}) {
  _applyReaderPreferences(
    jsonEncode({
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'margins': margins,
      'lineHeight': lineHeight,
      'wordWrap': wordWrap,
      'background': background,
      'foreground': foreground,
      'theme': theme,
    }).toJS,
  );
}

void goToReaderFragment(String? fragment) {
  if (fragment == null || fragment.isEmpty) return;
  _goToReaderFragment(fragment.toJS);
}

void highlightReaderSearch(String query, int occurrence) {
  _highlightReaderSearch(query.toJS, occurrence.toJS);
}

void clearReaderSearchHighlight() => _clearReaderSearch();
