import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'reader_screen.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.book});

  final Book book;

  String get _rentLabel =>
      '${book.rentalDays} күнгө ${book.rentalPrice} сомго ижарага алуу';

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
    try {
      await state.buy(book);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
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
        title: Text('${book.rentalDays} күнгө ижарага алуу'),
        content: Text(
          '«${book.title}» китеби ${book.rentalPrice} сомго ${book.rentalDays} күнгө жеткиликтүү болот.',
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
    try {
      await state.rent(book);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Китеп ${book.rentalDays} күнгө ижарага алынды')),
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
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text: Uri.base.resolve('/books/${book.slug}').toString(),
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Китептин шилтемеси көчүрүлдү')),
              );
            },
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
                        if (book.rating > 0 || book.readersCount > 0)
                          Row(
                            children: [
                              if (book.rating > 0) ...[
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF0A51A),
                                  size: 18,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  book.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (book.readersCount > 0) ...[
                                const Icon(
                                  Icons.people_outline_rounded,
                                  size: 16,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${book.readersCount} окурман',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
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
                    if (book.languageName != null)
                      _Fact(
                        icon: Icons.language_rounded,
                        label: book.languageName!,
                      ),
                    if (book.isAdult)
                      const _Fact(icon: Icons.person_outline, label: '18+'),
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
              if (book.publishedAt != null || book.updatedAt != null) ...[
                const SizedBox(height: 22),
                const Text(
                  'Китеп жөнүндө',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (book.publishedAt != null)
                  _InfoRow(
                    label: 'Kitapp\'та жарыяланган',
                    value: _formatDate(book.publishedAt!),
                  ),
                if (book.updatedAt != null)
                  _InfoRow(
                    label: 'Акыркы өзгөртүү',
                    value: _formatDate(book.updatedAt!),
                  ),
              ],
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
                ),
              if (book.isFree && !state.inLibrary(book)) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _confirmBuy(context, state),
                  icon: const Icon(Icons.library_add_outlined),
                  label: const Text('Китепканага кошуу'),
                ),
              ],
              if (!hasAccess && book.canBuy)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => _confirmBuy(context, state),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text('${book.price} сомго сатып алуу'),
                ),
              // Renters can upgrade to owning the book.
              if (state.isRented(book) &&
                  book.canBuy &&
                  !state.isPurchased(book)) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _confirmBuy(context, state),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text('Биротоло сатып алуу: ${book.price} сом'),
                ),
              ],
              if (!hasAccess && book.canRent) ...[
                if (book.canBuy) const SizedBox(height: 10),
                book.canBuy
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => _confirmRent(context, state),
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(_rentLabel),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: () => _confirmRent(context, state),
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(_rentLabel),
                      ),
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

const _months = [
  'январь',
  'февраль',
  'март',
  'апрель',
  'май',
  'июнь',
  'июль',
  'август',
  'сентябрь',
  'октябрь',
  'ноябрь',
  'декабрь',
];

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day}-${_months[local.month - 1]}, ${local.year}';
}
