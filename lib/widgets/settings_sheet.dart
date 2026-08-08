import 'package:flutter/material.dart';

class SettingsSheet extends StatefulWidget {
  final VoidCallback onDecreaseFont;

  final VoidCallback onIncreaseFont;

  final VoidCallback onDecreaseBrightness;

  final VoidCallback onIncreaseBrightness;

  final VoidCallback onLightTheme;

  final VoidCallback onSepiaTheme;

  final VoidCallback onDarkTheme;

  final String selectedTheme;

  const SettingsSheet({
    super.key,
    required this.onDecreaseFont,
    required this.onIncreaseFont,
    required this.onDecreaseBrightness,
    required this.onIncreaseBrightness,
    required this.onLightTheme,
    required this.onSepiaTheme,
    required this.onDarkTheme,
    required this.selectedTheme,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late String _selectedTheme;

  @override
  void initState() {
    super.initState();

    _selectedTheme = widget.selectedTheme;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.58,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F2EC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 6),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 4),

            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Артка',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                  ),

                  const Text(
                    'Жөндөө',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 0.6, color: Color(0xFFE8DED0)),

            const SizedBox(height: 24),

            _settingRow(
              icon: Icons.text_fields,
              title: 'Текст өлчөмү',
              onMinus: widget.onDecreaseFont,
              onPlus: widget.onIncreaseFont,
            ),

            const SizedBox(height: 12),

            _settingRow(
              icon: Icons.brightness_6,
              title: 'Жарыктыгы',
              onMinus: widget.onDecreaseBrightness,
              onPlus: widget.onIncreaseBrightness,
            ),

            const SizedBox(height: 18),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.swipe_rounded, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Барактоо',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Spacer(),
                  Text(
                    'Горизонталдуу',
                    style: TextStyle(
                      color: Color(0xFF0B6B35),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Тема',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            widget.onLightTheme();

                            setState(() {
                              _selectedTheme = 'light';
                            });
                          },
                          child: _themeButton(
                            'Күндүзгү',
                            _selectedTheme == 'light',
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            widget.onSepiaTheme();

                            setState(() {
                              _selectedTheme = 'sepia';
                            });
                          },
                          child: _themeButton(
                            'Сепия',
                            _selectedTheme == 'sepia',
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            widget.onDarkTheme();

                            setState(() {
                              _selectedTheme = 'dark';
                            });
                          },
                          child: _themeButton(
                            'Түнкү',
                            _selectedTheme == 'dark',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow({
    required IconData icon,
    required String title,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(icon, size: 20),

          const SizedBox(width: 10),

          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),

          const Spacer(),

          GestureDetector(
            onTap: onMinus,
            child: Container(
              width: 60,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('-', style: TextStyle(fontSize: 18)),
            ),
          ),

          const SizedBox(width: 8),

          GestureDetector(
            onTap: onPlus,
            child: Container(
              width: 60,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('+', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeButton(String title, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 30,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE4CDA8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(title, style: const TextStyle(fontSize: 12))),
    );
  }
}
