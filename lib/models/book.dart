enum BookAccess { free, purchase, rental }

class Book {
  const Book({
    required this.id,
    required this.slug,
    required this.title,
    required this.author,
    required this.category,
    required this.price,
    required this.pages,
    required this.rating,
    required this.coverStart,
    required this.coverEnd,
    required this.coverMark,
    this.coverUrl,
    this.rentalPrice,
    this.rentalDays,
    this.isAdult = false,
    this.isNew = false,
    this.access = BookAccess.purchase,
    this.description = '',
    this.readerAccess,
    this.rentalEndsAt,
    this.language,
    this.readersCount = 0,
    this.publishedAt,
    this.updatedAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? 'Аталышы жок';
    final seed = title.codeUnits.fold<int>(0, (value, item) => value + item);
    final access = switch (json['accessType']) {
      'FREE' => BookAccess.free,
      'RENTAL' => BookAccess.rental,
      _ => BookAccess.purchase,
    };
    return Book(
      id: json['id'].toString(),
      slug: json['slug']?.toString() ?? json['id'].toString(),
      title: title,
      author:
          (json['author'] as Map<String, dynamic>?)?['name']?.toString() ??
          'Белгисиз автор',
      category:
          (json['category'] as Map<String, dynamic>?)?['name']?.toString() ??
          'Башка',
      price: (json['price'] as num?)?.round() ?? 0,
      rentalPrice: (json['rentalPrice'] as num?)?.round(),
      rentalDays: (json['rentalDays'] as num?)?.round(),
      pages: (json['pages'] as num?)?.round() ?? 1,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      isAdult: json['isAdult'] == true,
      isNew: json['isNew'] == true,
      access: access,
      description: json['description']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString(),
      readerAccess: json['readerAccess']?.toString(),
      rentalEndsAt: json['rentalEndsAt'] == null
          ? null
          : DateTime.tryParse(json['rentalEndsAt'].toString()),
      language: json['language']?.toString(),
      readersCount: (json['readersCount'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      coverStart: _palette[seed % _palette.length].$1,
      coverEnd: _palette[seed % _palette.length].$2,
      coverMark: title.split(RegExp(r'\s+')).first.toUpperCase(),
    );
  }

  final String id;
  final String slug;
  final String title;
  final String author;
  final String category;
  final int price;
  final int? rentalPrice;
  final int? rentalDays;
  final int pages;
  final double rating;
  final int coverStart;
  final int coverEnd;
  final String coverMark;
  final String? coverUrl;
  final bool isAdult;
  final bool isNew;
  final BookAccess access;
  final String description;
  final String? readerAccess;
  final DateTime? rentalEndsAt;

  /// ISO language code from the EPUB (e.g. `ky`, `ru`), if known.
  final String? language;

  /// Readers who spent at least two minutes in the book.
  final int readersCount;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  String? get languageName =>
      switch (language?.split('-').first.toLowerCase()) {
        null || '' => null,
        'ky' => 'Кыргызча',
        'ru' => 'Орусча',
        'en' => 'Англисче',
        'kk' => 'Казакча',
        'uz' => 'Өзбекче',
        'tr' => 'Түркчө',
        'de' => 'Немисче',
        'fr' => 'Французча',
        final code => code.toUpperCase(),
      };

  // FREE = read for free; PURCHASE = buy (and rent if a rental price is set);
  // RENTAL = rent only. Mirrors the server rules.
  bool get isFree => access == BookAccess.free;
  bool get canBuy => access == BookAccess.purchase;
  bool get canRent =>
      access != BookAccess.free &&
      (rentalPrice ?? 0) > 0 &&
      (rentalDays ?? 0) > 0;
}

const _palette = <(int, int)>[
  (0xFF0B1918, 0xFF1C604B),
  (0xFF79533B, 0xFFF3C77B),
  (0xFF6B413E, 0xFFE9A284),
  (0xFF4F8FB5, 0xFFE9F3F5),
  (0xFF15112B, 0xFF6C5397),
  (0xFF32180C, 0xFFA96A36),
];
