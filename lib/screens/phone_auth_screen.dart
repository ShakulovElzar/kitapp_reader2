import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/book_widgets.dart';

/// Makes sure the reader is signed in before an action that needs an account
/// (buying, renting, reading). Guests see the sign-in screen first.
Future<bool> ensureSignedIn(BuildContext context) async {
  final state = AppStateScope.read(context);
  if (state.isAuthenticated) return true;
  final signedIn = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const PhoneAuthScreen(),
    ),
  );
  return signedIn == true && state.isAuthenticated;
}

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _codeSent = false;
  String? _developmentCode;
  bool _busy = false;
  String? _error;
  int _resendSeconds = 0;
  Timer? _timer;

  String get _fullPhone {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    return '+996${digits.startsWith('0') ? digits.substring(1) : digits}';
  }

  String get _displayPhone {
    final digits = _fullPhone.substring(4);
    if (digits.length != 9) return _fullPhone;
    return '+996 ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
  }

  Future<void> _requestCode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await AppStateScope.read(context).requestOtp(_fullPhone);
      if (!mounted) return;
      _startResendTimer();
      _code.clear();
      setState(() {
        _codeSent = true;
        _developmentCode = code;
      });
      _codeFocus.requestFocus();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Серверге туташуу мүмкүн болгон жок');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppStateScope.read(context).verifyOtp(_fullPhone, _code.text);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        _code.clear();
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Серверге туташуу мүмкүн болгон жок');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendTimer() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canClose = Navigator.of(context).canPop();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _codeSent ? _codeStep() : _phoneStep(canClose),
          ),
        ),
      ),
    );
  }

  Widget _phoneStep(bool canClose) {
    final covers = _carouselBooks(AppStateScope.of(context).visibleBooks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              const Text(
                'Kitapp',
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (canClose)
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Кийинчерээк'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 28, 0, 20),
            children: [
              // The carousel runs edge to edge; the form keeps side margins.
              if (covers.length >= 3) _CoverCarousel(books: covers),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Окуганыңыз ар бир түзмөктө сакталат',
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Кирүү үчүн сырсөз керек эмес. Номериңизге SMS код жөнөтөбүз.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Телефон номери',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phone,
                      enabled: !_busy,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                        LengthLimitingTextInputFormatter(12),
                      ],
                      onSubmitted: (_) => _requestCode(),
                      style: const TextStyle(fontSize: 17),
                      decoration: const InputDecoration(
                        hintText: '700 123 456',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 16, right: 8),
                          child: Text(
                            '+996',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(
                            color: AppColors.ink,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _busy ? null : _requestCode,
                child: _busy ? const _Spinner() : const Text('Код алуу'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Улантуу менен колдонуу шарттарына макул болосуз',
                textAlign: TextAlign.center,
                style: AppText.meta,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _codeStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Артка',
            onPressed: () => setState(() {
              _codeSent = false;
              _error = null;
            }),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SMS кодду жазыңыз', style: AppText.pageTitle),
              const SizedBox(height: 10),
              Text(
                '$_displayPhone номерине 6 сандуу код жөнөтүлдү.',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => setState(() => _codeSent = false),
                child: const Text('Номерди өзгөртүү'),
              ),
              const SizedBox(height: 20),
              _CodeBoxes(
                controller: _code,
                focusNode: _codeFocus,
                enabled: !_busy,
                onCompleted: _verify,
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 8),
              ],
              if (_resendSeconds > 0)
                Text(
                  'Кайра жөнөтүү 0:${_resendSeconds.toString().padLeft(2, '0')} кийин',
                  style: const TextStyle(fontSize: 15, color: AppColors.muted),
                )
              else
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _busy ? null : _requestCode,
                  child: const Text('Кодду кайра жөнөтүү'),
                ),
              if (_developmentCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Тест режими, код: $_developmentCode',
                    style: AppText.meta,
                  ),
                ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Код туура эмес болсо 5 жолу аракет кыла аласыз. Андан кийин жаңы код сураңыз.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Authors shown first in the sign-in carousel: Aitmatov, then Russian classics.
const _carouselAuthors = [
  'Айтматов',
  'Толстой',
  'Достоевский',
  'Пушкин',
  'Гоголь',
  'Чехов',
  'Тургенев',
  'Лермонтов',
  'Булгаков',
];

/// Aitmatov and Russian classics from the catalog, topped up with other covers
/// so the carousel is never sparse.
List<Book> _carouselBooks(List<Book> books) {
  int rank(Book book) {
    final index = _carouselAuthors.indexWhere(book.author.contains);
    return index < 0 ? _carouselAuthors.length : index;
  }

  final withCovers = books.where((book) => book.coverUrl != null).toList();
  final featured =
      withCovers.where((b) => rank(b) < _carouselAuthors.length).toList()
        ..sort((a, b) => rank(a).compareTo(rank(b)));
  final others = withCovers.where((b) => !featured.contains(b));
  return [...featured, ...others.take((8 - featured.length).clamp(0, 8))];
}

/// Covers drifting slowly to the left in an endless loop, slightly tilted
/// like books laid on a table. Stays still when the system asks for less motion.
class _CoverCarousel extends StatefulWidget {
  const _CoverCarousel({required this.books});

  final List<Book> books;

  @override
  State<_CoverCarousel> createState() => _CoverCarouselState();
}

class _CoverCarouselState extends State<_CoverCarousel>
    with SingleTickerProviderStateMixin {
  static const _width = 84.0;
  static const _height = 124.0;
  static const _gap = 16.0;
  static const _speed = 28.0; // pixels per second
  static const _tilts = [-.07, .04, -.03, .06, -.05, .02];

  late final AnimationController _controller = AnimationController(vsync: this);

  double get _cycle => widget.books.length * (_width + _gap);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = Duration(
      milliseconds: (_cycle / _speed * 1000).round(),
    );
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [...widget.books, ...widget.books];
    return ExcludeSemantics(
      child: SizedBox(
        height: _height + 24,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(-_controller.value * _cycle, 0),
              child: child,
            ),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, book) in items.indexed)
                    Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 20 : _gap / 2,
                        right: _gap / 2,
                        top: index.isEven ? 4 : 16,
                      ),
                      child: Transform.rotate(
                        angle: _tilts[index % _tilts.length],
                        child: BookCover(
                          book: book,
                          width: _width,
                          height: _height,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Six digit boxes drawn over one invisible text field, so paste and
/// SMS autofill keep working.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Box(
                        digit: i < text.length ? text[i] : '',
                        active: focusNode.hasFocus && i == text.length,
                        filled: i < text.length,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (value) {
                  if (value.length == 6) onCompleted();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.filled});

  final String digit;
  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? AppColors.green
              : filled
              ? AppColors.ink
              : AppColors.field,
          width: active ? 2 : 1.5,
        ),
        boxShadow: active
            ? const [BoxShadow(color: AppColors.greenSoft, spreadRadius: 3)]
            : null,
      ),
      child: Text(
        digit,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
