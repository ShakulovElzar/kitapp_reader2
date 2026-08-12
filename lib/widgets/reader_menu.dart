import 'package:flutter/material.dart';

class ReaderMenu extends StatelessWidget {
  final int currentPage;

  final bool showMenu;

  final double progress;

  final ValueChanged<double> onProgressChanged;

  final ValueChanged<double> onProgressChangeEnd;

  final VoidCallback onSettingsTap;

  final VoidCallback onContentsTap;

  final VoidCallback onSearchTap;

  final VoidCallback onBookmarkTap;

  final bool isBookmarked;

  final VoidCallback onBookmarkToggle;

  const ReaderMenu({
    super.key,
    required this.showMenu,
    required this.progress,
    required this.currentPage,
    required this.onProgressChanged,
    required this.onProgressChangeEnd,
    required this.onSettingsTap,
    required this.onContentsTap,
    required this.onSearchTap,
    required this.onBookmarkTap,
    required this.onBookmarkToggle,
    required this.isBookmarked,
  });

  Widget _menuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF4A4035), size: 22),

            const SizedBox(height: 4),

            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4A4035),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: 14,
      right: 14,
      bottom: showMenu ? 16 : -220,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: showMenu ? 1 : 0,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F2EC),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: const Color(0xFFE4CDA8),
                          inactiveTrackColor: const Color(0xFFE8DED0),
                          thumbColor: const Color(0xFFE4CDA8),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 20,
                          ),
                          overlayColor: Colors.transparent,
                        ),

                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: onProgressChanged,
                          onChangeEnd: onProgressChangeEnd,
                        ),
                      ),
                    ),

                    Semantics(
                      button: true,
                      label: isBookmarked
                          ? 'Кыстарманы өчүрүү'
                          : 'Кыстарма кошуу',
                      child: GestureDetector(
                        onTap: onBookmarkToggle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: const Color(0xFF5E9F73),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                Text(
                  '$currentPage-бет',
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      _menuButton(
                        icon: Icons.settings,
                        label: 'Жөндөө',
                        onTap: onSettingsTap,
                      ),

                      _menuButton(
                        icon: Icons.menu_book,
                        label: 'Мазмуну',
                        onTap: onContentsTap,
                      ),

                      _menuButton(
                        icon: Icons.search,
                        label: 'Издөө',
                        onTap: onSearchTap,
                      ),

                      _menuButton(
                        icon: Icons.bookmarks_outlined,
                        label: 'Кыстармалар',
                        onTap: onBookmarkTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
