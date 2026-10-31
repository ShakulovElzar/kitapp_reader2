import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/reader_palette.dart';

enum ReaderPanelTab { contents, settings }

/// Back and bookmark buttons shown at the top of the page while the panel is open.
class ReaderTopButtons extends StatelessWidget {
  const ReaderTopButtons({
    super.key,
    required this.visible,
    required this.isBookmarked,
    required this.onBack,
    required this.onBookmarkToggle,
  });

  final bool visible;
  final bool isBookmarked;
  final VoidCallback onBack;
  final VoidCallback onBookmarkToggle;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 10;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, top, 14, 0),
          child: Row(
            children: [
              _RoundButton(
                tooltip: 'Китептен чыгуу',
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.ink,
                  size: 19,
                ),
              ),
              const Spacer(),
              _RoundButton(
                tooltip: isBookmarked ? 'Белгини өчүрүү' : 'Белги коюу',
                onTap: onBookmarkToggle,
                child: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: AppColors.green,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
        shadowColor: const Color(0x33191B19),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// White bottom panel: reading position, then Contents / Text / Search.
class ReaderPanel extends StatelessWidget {
  const ReaderPanel({
    super.key,
    required this.visible,
    required this.tab,
    required this.onTabChanged,
    required this.onClose,
    required this.title,
    required this.author,
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.onProgressChanged,
    required this.onProgressChangeEnd,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBackTap,
    required this.onForwardTap,
    required this.onChaptersTap,
    required this.onBookmarksTap,
    required this.onSearchTap,
    required this.selectedTheme,
    required this.onThemeSelected,
    required this.fontFamily,
    required this.onFontChanged,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.margins,
    required this.onMarginsChanged,
    required this.lineHeight,
    required this.onLineHeightChanged,
    required this.brightness,
    required this.onBrightnessChanged,
    required this.hyphenate,
    required this.onHyphenateChanged,
    required this.onSettingsChangeEnd,
  });

  final bool visible;
  final ReaderPanelTab tab;
  final ValueChanged<ReaderPanelTab> onTabChanged;
  final VoidCallback onClose;

  final String title;
  final String author;
  final double progress;
  final int currentPage;
  final int totalPages;
  final ValueChanged<double> onProgressChanged;
  final ValueChanged<double> onProgressChangeEnd;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBackTap;
  final VoidCallback onForwardTap;
  final VoidCallback onChaptersTap;
  final VoidCallback onBookmarksTap;
  final VoidCallback onSearchTap;

  final String selectedTheme;
  final ValueChanged<String> onThemeSelected;
  final String fontFamily;
  final ValueChanged<String> onFontChanged;
  final int fontSize;
  final ValueChanged<int> onFontSizeChanged;
  final double margins;
  final ValueChanged<double> onMarginsChanged;
  final double lineHeight;
  final ValueChanged<double> onLineHeightChanged;
  final double brightness;
  final ValueChanged<double> onBrightnessChanged;
  final bool hyphenate;
  final ValueChanged<bool> onHyphenateChanged;

  /// Called when a slider drag ends, to persist the settings once.
  final VoidCallback onSettingsChangeEnd;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final settings = tab == ReaderPanelTab.settings;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(top: BorderSide(color: AppColors.line)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33191B19),
                    blurRadius: 30,
                    spreadRadius: -16,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + media.padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Semantics(
                      button: true,
                      label: 'Панелди жабуу',
                      child: GestureDetector(
                        onTap: onClose,
                        onVerticalDragEnd: (details) {
                          if ((details.primaryVelocity ?? 0) > 0) onClose();
                        },
                        child: Container(
                          width: 64,
                          height: 20,
                          alignment: Alignment.center,
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.field,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: settings
                        ? ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: media.size.height * .58,
                            ),
                            child: SingleChildScrollView(
                              child: _SettingsTab(panel: this),
                            ),
                          )
                        : _PositionTab(panel: this),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _PanelButton(
                        icon: Icons.format_list_bulleted_rounded,
                        label: 'Мазмуну',
                        onTap: onChaptersTap,
                      ),
                      const SizedBox(width: 8),
                      _PanelButton(
                        label: 'Текст',
                        glyph: 'Aa',
                        selected: settings,
                        onTap: () => onTabChanged(
                          settings
                              ? ReaderPanelTab.contents
                              : ReaderPanelTab.settings,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PanelButton(
                        icon: Icons.search_rounded,
                        label: 'Издөө',
                        onTap: onSearchTap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.glyph,
    this.selected = false,
  });

  final IconData? icon;
  final String? glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.ink;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.greenSoft : AppColors.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? AppColors.green : AppColors.line,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              height: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null)
                    Icon(icon, size: 21, color: color)
                  else
                    Text(
                      glyph!,
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: 18,
                        height: 1.15,
                        color: color,
                      ),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where you are in the book: page, a scrubber, jump history and bookmarks.
class _PositionTab extends StatelessWidget {
  const _PositionTab({required this.panel});

  final ReaderPanel panel;

  @override
  Widget build(BuildContext context) {
    final percent = (panel.progress * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          panel.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(panel.author, style: AppText.meta),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              '${panel.currentPage}-бет ${panel.totalPages}ден',
              style: AppText.meta,
            ),
            const Spacer(),
            Text('$percent%', style: AppText.meta),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: AppColors.green,
            inactiveTrackColor: AppColors.line,
            thumbColor: Colors.white,
            overlayColor: AppColors.green.withValues(alpha: .12),
            thumbShape: const _RingThumb(),
          ),
          child: Slider(
            padding: const EdgeInsets.symmetric(vertical: 12),
            value: panel.progress.clamp(0.0, 1.0),
            onChanged: panel.onProgressChanged,
            onChangeEnd: panel.onProgressChangeEnd,
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Мурунку орунга',
              onPressed: panel.canGoBack ? panel.onBackTap : null,
              icon: const Icon(Icons.undo_rounded, size: 20),
              color: AppColors.ink,
              disabledColor: AppColors.field,
            ),
            IconButton(
              tooltip: 'Кийинки орунга',
              onPressed: panel.canGoForward ? panel.onForwardTap : null,
              icon: const Icon(Icons.redo_rounded, size: 20),
              color: AppColors.ink,
              disabledColor: AppColors.field,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: panel.onBookmarksTap,
              icon: const Icon(Icons.bookmarks_outlined, size: 18),
              label: const Text('Белгилер'),
            ),
          ],
        ),
      ],
    );
  }
}

/// White thumb with a green ring, matching the design's scrubber.
class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(18);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = AppColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.panel});

  final ReaderPanel panel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Текст',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const _Label('Фон'),
        Row(
          children: [
            for (final theme in ReaderTheme.all) ...[
              Expanded(
                child: _ThemeSwatch(
                  theme: theme,
                  selected: theme.id == panel.selectedTheme,
                  onTap: () => panel.onThemeSelected(theme.id),
                ),
              ),
              if (theme != ReaderTheme.all.last) const SizedBox(width: 10),
            ],
          ],
        ),
        const _Label('Өлчөмү'),
        _SizeStepper(
          value: panel.fontSize,
          onChanged: (value) {
            panel.onFontSizeChanged(value);
            panel.onSettingsChangeEnd();
          },
        ),
        const _Label('Шрифт'),
        for (final (index, font) in readerFonts.indexed)
          InkWell(
            onTap: () => panel.onFontChanged(font),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: index < readerFonts.length - 1
                    ? const Border(
                        bottom: BorderSide(color: AppColors.lineSoft),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      font,
                      style: TextStyle(fontFamily: font, fontSize: 17),
                    ),
                  ),
                  if (font == panel.fontFamily)
                    const Icon(
                      Icons.check_rounded,
                      color: AppColors.green,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        const _Label('Сап аралыгы'),
        _LineSlider(
          value: (panel.lineHeight - 1.0) / 1.2,
          onChanged: (v) =>
              panel.onLineHeightChanged((10 + v * 12).round() / 10),
          onChangeEnd: panel.onSettingsChangeEnd,
        ),
        const _Label('Четтер'),
        _LineSlider(
          value: panel.margins / 48,
          onChanged: (v) => panel.onMarginsChanged((v * 12).round() * 4.0),
          onChangeEnd: panel.onSettingsChangeEnd,
        ),
        const _Label('Жарыктык'),
        _LineSlider(
          value: (panel.brightness - 0.3) / 0.7,
          onChanged: (v) => panel.onBrightnessChanged(0.3 + v * 0.7),
          onChangeEnd: panel.onSettingsChangeEnd,
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Сөздөрдү муунга бөлүү',
            style: TextStyle(fontSize: 15),
          ),
          value: panel.hyphenate,
          onChanged: panel.onHyphenateChanged,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: AppText.label),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Фон: ${theme.name}',
      child: Material(
        color: theme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? AppColors.green : AppColors.field,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Aa',
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 18,
                    height: 1.1,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  theme.name,
                  style: TextStyle(fontSize: 12, color: theme.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "A | 120% | A" stepper for the font size, 80–200% in steps of 10.
class _SizeStepper extends StatelessWidget {
  const _SizeStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget step(String tooltip, double size, int delta) => Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          final next = (value + delta).clamp(80, 200);
          if (next != value) onChanged(next);
        },
        child: SizedBox(
          width: 64,
          height: 46,
          child: Center(
            child: Text(
              'A',
              style: TextStyle(fontFamily: AppFonts.serif, fontSize: size),
            ),
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          step('Кичирээк', 15, -10),
          Expanded(
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: AppColors.line),
                ),
              ),
              child: Text(
                '$value%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          step('Чоңураак', 22, 10),
        ],
      ),
    );
  }
}

class _LineSlider extends StatelessWidget {
  const _LineSlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const _RingThumb(),
        overlayColor: AppColors.green.withValues(alpha: .12),
      ),
      child: Slider(
        padding: const EdgeInsets.symmetric(vertical: 8),
        value: value.clamp(0.0, 1.0),
        onChanged: onChanged,
        onChangeEnd: (_) => onChangeEnd(),
      ),
    );
  }
}
