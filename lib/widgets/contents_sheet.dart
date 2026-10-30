import 'package:flutter/material.dart';

import '../theme/reader_palette.dart';

/// Full-height dark list of chapters with their page numbers.
class ContentsSheet extends StatefulWidget {
  const ContentsSheet({
    super.key,
    required this.bookTitle,
    required this.chapters,
    required this.currentIndex,
    required this.chapterPages,
    required this.onChapterTap,
  });

  final String bookTitle;
  final List<String> chapters;
  final int currentIndex;
  final List<int> chapterPages;
  final ValueChanged<int> onChapterTap;

  @override
  State<ContentsSheet> createState() => _ContentsSheetState();
}

class _ContentsSheetState extends State<ContentsSheet> {
  static const _rowHeight = 61.0;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.currentIndex < 2) return;
      final target = (widget.currentIndex - 2) * _rowHeight;
      _scrollController.jumpTo(
        target.clamp(0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderListScaffold(
      title: 'БӨЛҮМДӨР',
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _ChapterRow(
            title: widget.bookTitle,
            page: 1,
            bold: true,
            indent: 0,
            highlighted: false,
            onTap: widget.chapters.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    widget.onChapterTap(0);
                  },
          ),
          for (var index = 0; index < widget.chapters.length; index++)
            _ChapterRow(
              title: widget.chapters[index],
              page: index < widget.chapterPages.length
                  ? widget.chapterPages[index]
                  : null,
              bold: false,
              indent: 22,
              highlighted: index == widget.currentIndex,
              onTap: () {
                Navigator.pop(context);
                widget.onChapterTap(index);
              },
            ),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.title,
    required this.page,
    required this.bold,
    required this.indent,
    required this.highlighted,
    required this.onTap,
  });

  final String title;
  final int? page;
  final bool bold;
  final double indent;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? ReaderPalette.card : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: _ContentsSheetState._rowHeight,
          margin: EdgeInsets.only(left: 20 + indent),
          padding: const EdgeInsets.only(right: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: ReaderPalette.divider)),
          ),
          child: Row(
            children: [
              if (highlighted)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 16,
                    color: ReaderPalette.bookmark,
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: bold || highlighted
                        ? Colors.white
                        : const Color(0xFFD9D8EE),
                    fontSize: 17,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
              if (page != null)
                Text(
                  '$page',
                  style: TextStyle(
                    color: bold ? Colors.white : ReaderPalette.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-height dark page with a round back button and a centered title,
/// shared by the chapters, bookmarks and search lists.
class ReaderListScaffold extends StatelessWidget {
  const ReaderListScaffold({
    super.key,
    required this.title,
    required this.child,
    this.header,
  });

  final String title;
  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Theme(
      data: ReaderPalette.theme(context),
      child: Container(
        height: height * 0.92,
        decoration: const BoxDecoration(
          gradient: ReaderPalette.panelGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ReaderPalette.divider),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: 'Артка',
                        child: Material(
                          color: ReaderPalette.backButton.withValues(alpha: .7),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: ReaderPalette.accent,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: ReaderPalette.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              ?header,
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
