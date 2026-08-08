import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openInfo(BuildContext context, String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InfoPage(title: title, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        children: [
          const Text(
            'Профиль',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            '+996 555 24 12 56',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          _ProfileGroup(
            children: [
              _ProfileRow(
                icon: Icons.menu_book_rounded,
                title: 'Сатып алуулар',
                subtitle: '${state.libraryBooks.length} китеп жеткиликтүү',
                onTap: () => _openInfo(
                  context,
                  'Сатып алуулар',
                  'Сатып алынган жана ижарага алынган китептер «Башкы китептер» бөлүмүндө сакталат.',
                ),
              ),
              _ProfileRow(
                icon: Icons.schedule_rounded,
                title: 'Активдүү ижаралар',
                subtitle:
                    '${state.libraryBooks.where(state.isRented).length} активдүү ижара',
                onTap: () => _openInfo(
                  context,
                  'Активдүү ижаралар',
                  'Ижарага алынган китептер жети күн бою жеткиликтүү. Мөөнөт китепканада көрсөтүлөт.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProfileGroup(
            children: [
              _ProfileRow(
                icon: Icons.support_agent_rounded,
                title: 'Биз менен байланышуу',
                subtitle: 'Суроолор жана колдоо',
                onTap: () => _openInfo(
                  context,
                  'Биз менен байланышуу',
                  'Колдоо кызматы: support@kitapp.kg\nИш убактысы: 09:00–18:00',
                ),
              ),
              _ProfileRow(
                icon: Icons.info_outline_rounded,
                title: 'Колдонмо жөнүндө',
                subtitle: 'Версия, шарттар жана купуялык',
                onTap: () => _openInfo(
                  context,
                  'Колдонмо жөнүндө',
                  'Kitapp — кыргыз тилиндеги электрондук китептерди окуу үчүн колдонмо.\n\nВерсия 1.0.0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '18+',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              title: const Text(
                '18+ мазмунду көрсөтүү',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Чоңдор үчүн мазмунду көрсөтүү',
                style: TextStyle(fontSize: 11),
              ),
              value: state.showAdult,
              onChanged: state.setShowAdult,
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              backgroundColor: const Color(0xFFFFF2F2),
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Чыгуу'),
                content: const Text('Демо-профилден чыгууну каалайсызбы?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Жок'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Ооба'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Чыгуу'),
          ),
        ],
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: AppColors.greenSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.green, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 10, color: AppColors.muted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: onTap,
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
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                body,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
