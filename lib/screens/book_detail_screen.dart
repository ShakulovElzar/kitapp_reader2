import 'package:flutter/material.dart';

import '../models/book.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'reader_screen.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.book});

  final Book book;

  Future<void> _confirmBuy(
    BuildContext context,
    AppStateController state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(book.isFree ? 'Китепти кошуу' : 'Сатып алуу'),
        content: Text(
          book.isFree
              ? '«${book.title}» китепканаңызга кошулат.'
              : '«${book.title}» китебин ${book.price} сомго сатып алууну ырастайсызбы?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ооба'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await state.buy(book);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Китеп китепканага кошулду')));
  }

  Future<void> _confirmRent(
    BuildContext context,
    AppStateController state,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('7 күнгө ижарага алуу'),
        content: Text(
          '«${book.title}» китеби 99 сомго 7 күнгө жеткиликтүү болот.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ижарага алуу'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await state.rent(book);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Китеп 7 күнгө ижарага алынды')),
    );
  }

  void _read(BuildContext context, AppStateController state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          book: book,
          onProgress: (value) => state.setProgress(book, value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final hasAccess = state.hasAccess(book);
    final rentalEnd = state.rentalEnd(book);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Бөлүшүү',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Китептин шилтемеси көчүрүлдү')),
            ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    book: book,
                    width: 132,
                    height: 194,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (book.isNew)
                          const Text(
                            'ЖАҢЫ КИТЕП',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                        const SizedBox(height: 5),
                        Text(
                          book.title,
                          style: const TextStyle(
                            fontSize: 24,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          book.author,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF0A51A),
                              size: 18,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${book.rating}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${1200 + book.pages}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Tag(text: book.category),
                            if (book.isAdult) const _Tag(text: '18+'),
                            if (hasAccess)
                              const _Tag(text: 'Сизде бар', accent: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    _Fact(
                      icon: Icons.description_outlined,
                      label: '${book.pages} бет',
                    ),
                    _Fact(icon: Icons.language_rounded, label: 'Кыргызча'),
                    const _Fact(icon: Icons.person_outline, label: '16+'),
                  ],
                ),
              ),
              if (rentalEnd != null && state.isRented(book)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warm,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Ижара мөөнөтү: ${rentalEnd.day}.${rentalEnd.month}.${rentalEnd.year} чейин',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              const Text(
                'Кыскача маалымат',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                book.description,
                style: const TextStyle(
                  color: Color(0xFF454A47),
                  height: 1.48,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Иш-чара маалыматы',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const _InfoRow(label: 'Басылып чыккан', value: '12-май, 2024'),
              const _InfoRow(label: 'Акыркы өзгөртүү', value: '19-май, 2024'),
              const SizedBox(height: 24),
              if (hasAccess)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _read(context, state),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(
                    state.progressFor(book) > 0
                        ? 'Окууну улантуу'
                        : 'Окууну баштоо',
                  ),
                )
              else ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _confirmBuy(context, state),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                    book.isFree
                        ? 'Китепканага кошуу'
                        : '${book.price} сомго сатып алуу',
                  ),
                ),
                if (!book.isFree) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _confirmRent(context, state),
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text('7 күнгө 99 сомго ижарага алуу'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.accent = false});
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? AppColors.greenSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent ? AppColors.green : AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.green, size: 20),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
