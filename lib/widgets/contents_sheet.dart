import 'package:flutter/material.dart';

class ContentsSheet extends StatefulWidget {
  final List<String> chapters;

  final int currentIndex;

  final List<int> chapterPages;

  final ValueChanged<int> onChapterTap;

  const ContentsSheet({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.chapterPages,
    required this.onChapterTap,
  });

  @override
  State<ContentsSheet> createState() => _ContentsSheetState();
}

class _ContentsSheetState extends State<ContentsSheet> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.currentIndex < 0) {
        return;
      }

      final offset = (widget.currentIndex * 52).toDouble();

      _scrollController.jumpTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F2EC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7CABB),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      label: 'Артка',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: Color(0xFF4A4035),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Text(
                    'Мазмуну',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A4035),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE7DCCF)),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                itemCount: widget.chapters.length,
                itemBuilder: (context, index) {
                  final isCurrent = index == widget.currentIndex;

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.pop(context);

                      widget.onChapterTap(index);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFFE8D7BE)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.chapters[index],
                              style: TextStyle(
                                color: const Color(0xFF4A4035),
                                fontSize: 15,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          if (index < widget.chapterPages.length) ...[
                            Text(
                              '${widget.chapterPages[index]}',
                              style: const TextStyle(
                                color: Color(0xFF8E775D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Icon(
                            isCurrent
                                ? Icons.play_arrow_rounded
                                : Icons.chevron_right,
                            size: 18,
                            color: const Color(0xFF8E775D),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
