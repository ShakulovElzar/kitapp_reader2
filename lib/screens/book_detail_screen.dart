import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../services/api_client.dart';
import '../services/launch_link.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';
import 'home_screen.dart';
import 'phone_auth_screen.dart';
import 'routes.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.book});

  final Book book;

  Future<void> _confirmBuy(
    BuildContext context,
    AppStateController state,
  ) async {
    if (!await ensureSignedIn(context) || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(book.isFree ? 'Текчеге кошуу' : 'Сатып алуу'),
        content: Text(
          book.isFree
              ? '«${book.title}» текчеңизге кошулат.'
              : '«${book.title}» китебин ${book.price} сомго сатып алууну ырастайсызбы?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(book.isFree ? 'Кошуу' : '${book.price} сом төлөө'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          book.isFree
              ? 'Китеп текчеңизге кошулду'
              : 'Китеп сиздики. Окуп баштасаңыз болот',
        ),
      ),
    );
  }

  Future<void> _confirmRent(
    BuildContext context,
    AppStateController state,
  ) async {
    if (!await ensureSignedIn(context) || !context.mounted) return;
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('${book.rentalPrice} сом төлөө'),
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

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final hasAccess = state.hasAccess(book);
    final rented = state.isRented(book);
    final rentalEnd = state.rentalEnd(book);
    final meta = [
      book.category,
      if (book.isAdult) '18+',
      ?book.languageName,
      if (book.pages > 1) '${book.pages} бет',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Бөлүшүү',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  // The app opens `?book=<slug>` links on start (see AppShell).
                  text: (launchUrl() ?? Uri.base)
                      .replace(queryParameters: {'book': book.slug})
                      .removeFragment()
                      .toString(),
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Китептин шилтемеси көчүрүлдү')),
              );
            },
            icon: const Icon(Icons.ios_share_rounded, size: 21),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            children: [
              Center(
                child: BookCover(
                  book: book,
                  width: 150,
                  height: 222,
                  lifted: true,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                book.title,
                textAlign: TextAlign.center,
                style: AppText.bookTitle.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                book.author,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Text(meta, textAlign: TextAlign.center, style: AppText.meta),
              if (rented && rentalEnd != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Ижара ${formatDay(rentalEnd)} чейин',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.warm),
                ),
              ] else if (state.inLibrary(book)) ...[
                const SizedBox(height: 8),
                const Text(
                  'Текчеңизде бар',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.green),
                ),
              ],
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 18),
              if (book.description.trim().isNotEmpty)
                _Description(text: book.description),
              if (book.publishedAt != null || book.updatedAt != null) ...[
                const SizedBox(height: 22),
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: _ActionBar(
        children: [
          if (hasAccess) ...[
            FilledButton(
              onPressed: () => openReader(context, book),
              child: Text(
                state.progressFor(book) > 0 ? 'Окууну улантуу' : 'Окуп баштоо',
              ),
            ),
            if (rented && book.canBuy && !state.isPurchased(book))
              TextButton(
                onPressed: () => _confirmBuy(context, state),
                child: Text('Биротоло сатып алуу · ${book.price} сом'),
              )
            else if (book.isFree && !state.inLibrary(book))
              TextButton(
                onPressed: () => _confirmBuy(context, state),
                child: const Text('Текчеге кошуу'),
              ),
          ] else if (book.canBuy) ...[
            _PriceButton(
              label: 'Сатып алуу',
              price: '${book.price} сом',
              onPressed: () => _confirmBuy(context, state),
            ),
            if (book.canRent)
              TextButton(
                onPressed: () => _confirmRent(context, state),
                child: Text(
                  'Же ${book.rentalDays} күнгө ижара · ${book.rentalPrice} сом',
                ),
              ),
          ] else if (book.canRent)
            _PriceButton(
              label: '${book.rentalDays} күнгө ижара',
              price: '${book.rentalPrice} сом',
              onPressed: () => _confirmRent(context, state),
            ),
        ],
      ),
    );
  }
}

/// Bottom bar that holds the page's one main action.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({
    required this.label,
    required this.price,
    required this.onPressed,
  });

  final String label;
  final String price;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(price),
        ],
      ),
    );
  }
}

class _Description extends StatefulWidget {
  const _Description({required this.text});

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 16,
      height: 1.6,
      color: AppColors.body,
    );
    final long = widget.text.length > 260;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: style,
          maxLines: _expanded || !long ? null : 5,
          overflow: _expanded || !long ? null : TextOverflow.ellipsis,
        ),
        if (long)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Кыскараак' : 'Толугураак'),
          ),
      ],
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
          Expanded(child: Text(label, style: AppText.meta)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
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
