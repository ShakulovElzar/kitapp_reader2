import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chapter list with page numbers; the current chapter is marked in green.
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
  static const _rowHeight = 52.0;
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
      title: widget.bookTitle,
      subtitle: 'Мазмуну',
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
    final color = highlighted
        ? AppColors.green
        : bold
        ? AppColors.ink
        : AppColors.body;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: _ContentsSheetState._rowHeight,
        margin: EdgeInsets.only(left: 20 + indent / 2, right: 20),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
        ),
        child: Row(
          children: [
            if (highlighted)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: bold || highlighted
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            if (page != null)
              Text(
                '$page',
                style: highlighted
                    ? const TextStyle(fontSize: 13, color: AppColors.green)
                    : AppText.meta,
              ),
          ],
        ),
      ),
    );
  }
}

/// White sheet with a drag handle, a title and a close button, shared by
/// the chapters, bookmarks and search lists.
class ReaderListScaffold extends StatelessWidget {
  const ReaderListScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.header,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Container(
      height: height * 0.86,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: AppColors.field,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null)
                          Text(subtitle!, style: AppText.label),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Жабуу',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(),
            ?header,
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
