import 'package:flutter/material.dart';

import '../theme/reader_palette.dart';

enum ReaderPanelTab { contents, settings }

/// Round buttons shown at the top of the page while the panel is open.
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
    final top = MediaQuery.of(context).padding.top + 12;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top, 16, 0),
          child: Row(
            children: [
              _RoundButton(
                tooltip: 'Чыгуу',
                color: ReaderPalette.backButton,
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Spacer(),
              _RoundButton(
                tooltip: isBookmarked ? 'Кыстарманы өчүрүү' : 'Кыстарма кошуу',
                color: Colors.white,
                border: const Color(0x22000000),
                onTap: onBookmarkToggle,
                child: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: ReaderPalette.bookmark,
                  size: 28,
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
    required this.color,
    required this.onTap,
    required this.child,
    this.border,
  });

  final String tooltip;
  final Color color;
  final Color? border;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: CircleBorder(
          side: border == null ? BorderSide.none : BorderSide(color: border!),
        ),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 52, height: 52, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Dark bottom panel with Contents / Settings tabs and a Search shortcut.
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Theme(
          data: ReaderPalette.theme(context),
          child: Container(
            decoration: const BoxDecoration(
              gradient: ReaderPalette.panelGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PanelHeader(
                  title: tab == ReaderPanelTab.contents
                      ? 'МАЗМУНУ'
                      : 'ЖӨНДӨӨЛӨР',
                  onClose: onClose,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: tab == ReaderPanelTab.contents
                      ? _ContentsTab(panel: this)
                      : _SettingsTab(panel: this),
                ),
                const Divider(height: 1, color: ReaderPalette.divider),
                _TabBar(
                  tab: tab,
                  onTabChanged: onTabChanged,
                  onSearchTap: onSearchTap,
                ),
                SizedBox(height: bottomInset),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ReaderPalette.divider)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ReaderPalette.accent,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'Жабуу',
            child: Material(
              color: const Color(0xFF0E0D24),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClose,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: ReaderPalette.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tab,
    required this.onTabChanged,
    required this.onSearchTap,
  });

  final ReaderPanelTab tab;
  final ValueChanged<ReaderPanelTab> onTabChanged;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _TabButton(
            icon: Icons.menu_book_outlined,
            label: 'Мазмуну',
            selected: tab == ReaderPanelTab.contents,
            onTap: () => onTabChanged(ReaderPanelTab.contents),
          ),
          _TabButton(
            icon: Icons.tune_rounded,
            label: 'Жөндөөлөр',
            selected: tab == ReaderPanelTab.settings,
            onTap: () => onTabChanged(ReaderPanelTab.settings),
          ),
          _TabButton(
            icon: Icons.search_rounded,
            label: 'Издөө',
            selected: false,
            onTap: onSearchTap,
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : ReaderPalette.accent;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentsTab extends StatelessWidget {
  const _ContentsTab({required this.panel});

  final ReaderPanel panel;

  @override
  Widget build(BuildContext context) {
    final percent = (panel.progress * 100).clamp(0, 100);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            panel.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            panel.author,
            style: const TextStyle(
              color: ReaderPalette.muted,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: ReaderPalette.bookmark,
              inactiveTrackColor: const Color(0xFF4A4870),
              thumbColor: Colors.white,
              overlayColor: ReaderPalette.bookmark.withValues(alpha: .2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              padding: EdgeInsets.zero,
              value: panel.progress.clamp(0.0, 1.0),
              onChanged: panel.onProgressChanged,
              onChangeEnd: panel.onProgressChangeEnd,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${percent.toStringAsFixed(percent < 10 ? 1 : 0)}%',
                style: const TextStyle(color: ReaderPalette.muted),
              ),
              const Spacer(),
              _HistoryArrow(
                icon: Icons.undo_rounded,
                tooltip: 'Мурунку орун',
                onTap: panel.canGoBack ? panel.onBackTap : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${panel.currentPage} / ${panel.totalPages}-бет',
                  style: const TextStyle(color: ReaderPalette.muted),
                ),
              ),
              _HistoryArrow(
                icon: Icons.redo_rounded,
                tooltip: 'Кийинки орун',
                onTap: panel.canGoForward ? panel.onForwardTap : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.format_list_bulleted_rounded,
                  iconColor: Colors.white,
                  label: 'Бөлүмдөр',
                  onTap: panel.onChaptersTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.bookmark_rounded,
                  iconColor: ReaderPalette.bookmark,
                  label: 'Кыстармалар',
                  onTap: panel.onBookmarksTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryArrow extends StatelessWidget {
  const _HistoryArrow({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: ReaderPalette.accent,
      disabledColor: ReaderPalette.divider,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ReaderPalette.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: ReaderPalette.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.panel});

  final ReaderPanel panel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: [
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
                if (theme != ReaderTheme.all.last) const SizedBox(width: 14),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _FontPicker(
            fontFamily: panel.fontFamily,
            onChanged: panel.onFontChanged,
          ),
          const Divider(height: 24, color: ReaderPalette.divider),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => panel.onHyphenateChanged(!panel.hyphenate),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _RoundCheck(checked: panel.hyphenate),
                  const SizedBox(width: 12),
                  const Text(
                    'Сөздөрдү муунга бөлүү',
                    style: TextStyle(color: ReaderPalette.muted, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VerticalLevel(
                icon: Icons.text_fields_rounded,
                label: 'Тамга\nөлчөмү',
                value: (panel.fontSize - 80) / 120,
                onChanged: (v) =>
                    panel.onFontSizeChanged(((80 + v * 120) / 10).round() * 10),
                onChangeEnd: panel.onSettingsChangeEnd,
              ),
              _VerticalLevel(
                icon: Icons.article_outlined,
                label: 'Четтер',
                value: panel.margins / 48,
                onChanged: (v) =>
                    panel.onMarginsChanged((v * 12).round() * 4.0),
                onChangeEnd: panel.onSettingsChangeEnd,
              ),
              _VerticalLevel(
                icon: Icons.format_line_spacing_rounded,
                label: 'Сап\nаралыгы',
                value: (panel.lineHeight - 1.0) / 1.2,
                onChanged: (v) =>
                    panel.onLineHeightChanged((10 + v * 12).round() / 10),
                onChangeEnd: panel.onSettingsChangeEnd,
              ),
              _VerticalLevel(
                icon: Icons.wb_sunny_outlined,
                label: 'Жарыктык',
                value: (panel.brightness - 0.3) / 0.7,
                onChanged: (v) => panel.onBrightnessChanged(0.3 + v * 0.7),
                onChangeEnd: panel.onSettingsChangeEnd,
              ),
            ],
          ),
        ],
      ),
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
      label: 'Тема: ${theme.id}',
      child: Material(
        color: theme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? ReaderPalette.accent : const Color(0xFF8E8CB0),
            width: selected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: selected
                ? Icon(Icons.check_rounded, color: theme.text, size: 22)
                : null,
          ),
        ),
      ),
    );
  }
}

class _FontPicker extends StatefulWidget {
  const _FontPicker({required this.fontFamily, required this.onChanged});

  final String fontFamily;
  final ValueChanged<String> onChanged;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  late final PageController _controller = PageController(initialPage: _index);

  int get _index =>
      readerFonts.indexOf(widget.fontFamily).clamp(0, readerFonts.length - 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = (_index + delta) % readerFonts.length;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Шрифт',
          style: TextStyle(color: ReaderPalette.muted, fontSize: 16),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Мурунку шрифт',
          visualDensity: VisualDensity.compact,
          color: ReaderPalette.accent,
          onPressed: () => _step(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: readerFonts.length,
                  onPageChanged: (index) =>
                      widget.onChanged(readerFonts[index]),
                  itemBuilder: (context, index) => Center(
                    child: Text(
                      readerFonts[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: readerFonts[index],
                        fontSize: 21,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < readerFonts.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? Colors.white
                            : ReaderPalette.muted.withValues(alpha: .5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Кийинки шрифт',
          visualDensity: VisualDensity.compact,
          color: ReaderPalette.accent,
          onPressed: () => _step(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _RoundCheck extends StatelessWidget {
  const _RoundCheck({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? ReaderPalette.accentStrong : const Color(0xFF1C1A3D),
        border: Border.all(color: ReaderPalette.divider),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : null,
    );
  }
}

/// Tall rounded bar that fills from the bottom; drag or tap to set a 0–1 value.
class _VerticalLevel extends StatelessWidget {
  const _VerticalLevel({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  static const _height = 150.0;

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  void _update(Offset local) {
    onChanged((1 - local.dy / _height).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final level = value.clamp(0.0, 1.0);
    final fill = 44 + level * (_height - 44);
    return Expanded(
      child: Column(
        children: [
          Semantics(
            slider: true,
            label: label.replaceAll('\n', ' '),
            value: '${(level * 100).round()}%',
            onIncrease: () {
              onChanged((level + 0.1).clamp(0.0, 1.0));
              onChangeEnd();
            },
            onDecrease: () {
              onChanged((level - 0.1).clamp(0.0, 1.0));
              onChangeEnd();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (d) => _update(d.localPosition),
              onVerticalDragUpdate: (d) => _update(d.localPosition),
              onVerticalDragEnd: (_) => onChangeEnd(),
              onTapUp: (d) {
                _update(d.localPosition);
                onChangeEnd();
              },
              child: Container(
                width: 64,
                height: _height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF26234C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ReaderPalette.divider),
                ),
                child: Stack(
                  children: [
                    for (var i = 1; i < 4; i++)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: _height * i / 4,
                        child: Container(
                          height: 1,
                          color: ReaderPalette.divider.withValues(alpha: .6),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: fill,
                      child: Container(
                        color: ReaderPalette.accentStrong,
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ReaderPalette.muted,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
