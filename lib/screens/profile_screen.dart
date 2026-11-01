import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'phone_auth_screen.dart';
import 'routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openInfo(BuildContext context, String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InfoPage(title: title, body: body),
      ),
    );
  }

  String _formatPhone(String phone) {
    // Older sessions stored the number as typed ("0700112299").
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('996')
        ? digits.substring(3)
        : digits.startsWith('0')
        ? digits.substring(1)
        : digits;
    final match = RegExp(r'^(\d{3})(\d{3})(\d{3})$').firstMatch(local);
    if (match == null) return phone;
    return '+996 ${match[1]} ${match[2]} ${match[3]}';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final books = state.libraryBooks;
    final finished = books.where(state.isFinished).length;
    final rented = books.where(state.isRented).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const Text('Профиль', style: AppText.pageTitle),
          const SizedBox(height: 6),
          if (state.isAuthenticated) ...[
            Text(
              _formatPhone(state.phone),
              style: const TextStyle(fontSize: 16, color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: const BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppColors.line),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _Count(value: finished, label: 'окулуп бүттү'),
                    const VerticalDivider(width: 1),
                    _Count(value: state.purchasedCount, label: 'сатып алынган'),
                    const VerticalDivider(width: 1),
                    _Count(value: rented, label: 'ижарада'),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Сатып алган китептериңиз жана окуган жериңиз сакталышы үчүн кириңиз.',
              style: AppText.body,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ensureSignedIn(context),
              child: const Text('Кирүү'),
            ),
          ],
          if (state.isAuthenticated) ...[
            const _GroupLabel('Китептер'),
            LinkRow(
              title: 'Текчем',
              value: '${books.length}',
              onTap: () => openShelf(context),
              divider: false,
            ),
          ],
          const _GroupLabel('Окуу'),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '18+ китептерди көрсөтүү',
                style: TextStyle(fontSize: 16),
              ),
              subtitle: const Text(
                'Каталогдо жана издөөдө',
                style: AppText.meta,
              ),
              value: state.showAdult,
              onChanged: state.setShowAdult,
            ),
          ),
          const _GroupLabel('Жардам'),
          LinkRow(
            title: 'Биз менен байланышуу',
            onTap: () => _openInfo(
              context,
              'Биз менен байланышуу',
              'Колдоо кызматы: support@kitapp.kg\nИш убактысы: 09:00–18:00',
            ),
          ),
          LinkRow(
            title: 'Колдонмо жөнүндө',
            divider: false,
            onTap: () => _openInfo(
              context,
              'Колдонмо жөнүндө',
              'Kitapp — кыргыз тилиндеги электрондук китептерди окуу үчүн колдонмо.\n\nВерсия 1.0.0',
            ),
          ),
          if (state.isAuthenticated) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Чыгуу'),
                    content: const Text('Профилден чыгууну каалайсызбы?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Жок'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await state.logout();
                        },
                        child: const Text('Чыгуу'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Чыгуу'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppText.meta),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(title, style: AppText.pageTitle),
              const SizedBox(height: 16),
              Text(body, style: AppText.body),
            ],
          ),
        ),
      ),
    );
  }
}
