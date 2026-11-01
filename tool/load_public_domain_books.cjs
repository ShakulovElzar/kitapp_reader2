const assert = require('node:assert/strict');

const apiUrl = process.env.KITAPP_API_URL || 'http://127.0.0.1:3000/api';

const books = [
  { id: 11, slug: 'alice-wonderland', title: 'Алиса кереметтер өлкөсүндө', author: 'Льюис Кэрролл', category: 'Балдар үчүн', pages: 192, description: 'Алисанын кереметтүү дүйнөдөгү укмуштуу саякаты. Түпнуска англис тилинде.' },
  { id: 1342, slug: 'pride-prejudice', title: 'Текебердик жана жаңылыш пикир', author: 'Жейн Остин', category: 'Роман', pages: 432, description: 'Элизабет Беннет менен мистер Дарсинин мамилеси тууралуу классикалык роман. Түпнуска англис тилинде.' },
  { id: 1661, slug: 'sherlock-holmes', title: 'Шерлок Холмстун жоруктары', author: 'Артур Конан Дойл', category: 'Детектив', pages: 352, description: 'Шерлок Холмстун он эки белгилүү иликтөөсү. Түпнуска англис тилинде.' },
  { id: 84, slug: 'frankenstein', title: 'Франкенштейн', author: 'Мэри Шелли', category: 'Фантастика', pages: 280, description: 'Илимпоз жана ал жараткан жандык тууралуу готикалык классика. Түпнуска англис тилинде.' },
  { id: 2701, slug: 'moby-dick', title: 'Моби Дик', author: 'Герман Мелвилл', category: 'Роман', pages: 720, description: 'Капитан Ахабдын ак киттин артынан түшкөн деңиз сапары. Түпнуска англис тилинде.' },
  { id: 345, slug: 'dracula', title: 'Дракула', author: 'Брэм Стокер', category: 'Коркунучтуу', pages: 416, description: 'Граф Дракула жөнүндөгү эпистолярдык готикалык роман. Түпнуска англис тилинде.' },
  { id: 98, slug: 'tale-two-cities', title: 'Эки шаардын баяны', author: 'Чарльз Диккенс', category: 'Тарыхый', pages: 448, description: 'Лондон менен Париждеги Француз революциясынын доорундагы тагдырлар. Түпнуска англис тилинде.' },
  { id: 120, slug: 'treasure-island', title: 'Казына аралы', author: 'Роберт Льюис Стивенсон', category: 'Балдар үчүн', pages: 240, description: 'Каракчылар, карта жана жашырылган казына тууралуу укмуштуу окуя. Түпнуска англис тилинде.' },

  // Test set with every access type. Prices are for testing the buy/rent flows only.
  // Free
  { id: 46, slug: 'christmas-carol', title: 'Рождество жомогу', author: 'Чарльз Диккенс', category: 'Роман', pages: 104, isNew: true, description: 'Сараң Скруждун Рождество түнүндөгү арбактар менен жолугушуусу. Түпнуска англис тилинде.' },
  { id: 16, slug: 'peter-pan', title: 'Питер Пэн', author: 'Жеймс Барри', category: 'Балдар үчүн', pages: 208, description: 'Эч качан чоңойбогон бала жана Жок-Жок аралы. Түпнуска англис тилинде.' },
  { id: 55, slug: 'wizard-of-oz', title: 'Оз өлкөсүнүн сыйкырчысы', author: 'Фрэнк Баум', category: 'Балдар үчүн', pages: 176, description: 'Дороти жана анын досторунун Изумруд шаарына саякаты. Түпнуска англис тилинде.' },
  { id: 2591, slug: 'grimm-fairy-tales', title: 'Гримм бир туугандардын жомоктору', author: 'Гримм бир туугандар', category: 'Балдар үчүн', pages: 320, description: 'Белгилүү немис эл жомокторунун жыйнагы. Англис тилинде.' },
  { id: 35, slug: 'time-machine', title: 'Убакыт машинасы', author: 'Герберт Уэллс', category: 'Фантастика', pages: 112, isNew: true, description: 'Алыскы келечекке саякаттаган ойлоп табуучунун баяны. Түпнуска англис тилинде.' },
  { id: 103, slug: 'around-world-80-days', title: 'Сексен күндө дүйнө айланып', author: 'Жюль Верн', category: 'Укмуштуу окуялар', pages: 256, description: 'Филеас Фоггдун дүйнөнү 80 күндө айланып чыгуу боюнча мелдеши. Англис тилинде.' },
  // Paid (one marked 18+ to test the adult filter)
  { id: 174, slug: 'dorian-gray', title: 'Дориан Грейдин портрети', author: 'Оскар Уайльд', category: 'Роман', pages: 272, accessType: 'PURCHASE', price: 149, isAdult: true, description: 'Жаштыгын сактап, жанын сүрөткө берген жигит тууралуу роман. Түпнуска англис тилинде.' },
  { id: 768, slug: 'wuthering-heights', title: 'Шамалдуу дөбөлөр', author: 'Эмили Бронте', category: 'Драма', pages: 400, accessType: 'PURCHASE', price: 129, description: 'Хитклиф менен Кэтриндин кайгылуу сүйүүсү. Түпнуска англис тилинде.' },
  { id: 2852, slug: 'hound-baskervilles', title: 'Баскервилдердин ити', author: 'Артур Конан Дойл', category: 'Детектив', pages: 256, accessType: 'PURCHASE', price: 99, isNew: true, description: 'Шерлок Холмс жана Баскервилдер үй-бүлөсүнүн каргышы. Түпнуска англис тилинде.' },
  // Paid with an optional rental
  { id: 1400, slug: 'great-expectations', title: 'Улуу үмүттөр', author: 'Чарльз Диккенс', category: 'Роман', pages: 544, accessType: 'PURCHASE', price: 199, rentalPrice: 49, rentalDays: 14, description: 'Жетим Пиптин тагдыры жана анын улуу үмүттөрү. Түпнуска англис тилинде.' },
  { id: 1399, slug: 'anna-karenina', title: 'Анна Каренина', author: 'Лев Толстой', category: 'Драма', pages: 864, accessType: 'PURCHASE', price: 249, rentalPrice: 69, rentalDays: 14, description: 'Сүйүү, үй-бүлө жана коом тууралуу улуу роман. Англис тилине которулган.' },
  { id: 2554, slug: 'crime-and-punishment', title: 'Кылмыш жана жаза', author: 'Федор Достоевский', category: 'Роман', pages: 576, accessType: 'PURCHASE', price: 249, rentalPrice: 69, rentalDays: 14, isNew: true, description: 'Раскольниковдун кылмышы жана абийир азабы. Англис тилине которулган.' },
  { id: 1184, slug: 'count-monte-cristo', title: 'Монте-Кристо графы', author: 'Александр Дюма', category: 'Укмуштуу окуялар', pages: 1276, accessType: 'PURCHASE', price: 299, rentalPrice: 79, rentalDays: 21, description: 'Эдмон Дантестин түрмөдөн качып, өч алуусу. Англис тилине которулган.' },
  // Rental only
  { id: 1260, slug: 'jane-eyre', title: 'Жейн Эйр', author: 'Шарлотта Бронте', category: 'Драма', pages: 512, accessType: 'RENTAL', price: 0, rentalPrice: 59, rentalDays: 14, description: 'Жетим кыздын өз ордун издеген өмүр баяны. Түпнуска англис тилинде.' },
  { id: 36, slug: 'war-of-the-worlds', title: 'Дүйнөлөр согушу', author: 'Герберт Уэллс', category: 'Фантастика', pages: 224, accessType: 'RENTAL', price: 0, rentalPrice: 39, rentalDays: 7, description: 'Марстыктардын Жерге басып киришин баяндаган классикалык фантастика. Түпнуска англис тилинде.' },
];

const ORIGINAL_DEMO_IDS = new Set([11, 1342, 1661, 84, 2701, 345, 98, 120]);

async function request(path, { token, method = 'GET', body } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body && !(body instanceof FormData)) headers['Content-Type'] = 'application/json';
  const response = await fetch(`${apiUrl}${path}`, {
    method,
    headers,
    body: body instanceof FormData ? body : body ? JSON.stringify(body) : undefined,
  });
  const value = await response.json().catch(() => null);
  assert.ok(response.ok, `${method} ${path}: ${JSON.stringify(value)}`);
  return value;
}

async function download(url) {
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const response = await fetch(url, {
        redirect: 'follow',
        signal: AbortSignal.timeout(30_000),
      });
      assert.ok(response.ok, `GET ${url}: ${response.status}`);
      return Buffer.from(await response.arrayBuffer());
    } catch (error) {
      lastError = error;
      console.warn(`RETRY ${attempt}/3 ${url}`);
    }
  }
  throw lastError;
}

(async () => {
  const login = await request('/auth/admin/login', {
    method: 'POST',
    body: {
      email: process.env.ADMIN_EMAIL || 'admin@kitapp.kg',
      password: process.env.ADMIN_PASSWORD || 'Kitapp123!',
    },
  });
  const [authors, categories, existingBooks] = await Promise.all([
    request('/admin/authors', { token: login.token }),
    request('/admin/categories', { token: login.token }),
    request('/admin/books', { token: login.token }),
  ]);
  const authorByName = new Map(authors.map((item) => [item.name, item]));
  const categoryByName = new Map(categories.map((item) => [item.name, item]));
  const existingSlugs = new Set(existingBooks.map((item) => item.slug));

  for (const book of books) {
    if (existingSlugs.has(book.slug)) {
      console.log(`SKIP ${book.title}`);
      continue;
    }
    let author = authorByName.get(book.author);
    if (!author) {
      author = await request('/admin/authors', { token: login.token, method: 'POST', body: { name: book.author } });
      authorByName.set(book.author, author);
    }
    let category = categoryByName.get(book.category);
    if (!category) {
      category = await request('/admin/categories', {
        token: login.token,
        method: 'POST',
        body: { name: book.category, slug: `public-${book.category.toLowerCase().replaceAll(' ', '-')}` },
      });
      categoryByName.set(book.category, category);
    }
    const epubUrl = `https://www.gutenberg.org/ebooks/${book.id}.epub.noimages`;
    const coverUrl = `https://www.gutenberg.org/cache/epub/${book.id}/pg${book.id}.cover.medium.jpg`;
    let epub;
    let cover;
    try {
      [epub, cover] = await Promise.all([download(epubUrl), download(coverUrl)]);
    } catch (error) {
      console.warn(`FAIL ${book.title}: ${error.message}`);
      continue;
    }
    const form = new FormData();
    form.set('data', JSON.stringify({
      title: book.title,
      slug: book.slug,
      description: `${book.description}\n\nБулак: Project Gutenberg, eBook №${book.id}. Коомдук домен (АКШ).`,
      authorId: author.id,
      categoryId: category.id,
      price: book.price ?? 0,
      rentalPrice: book.rentalPrice ?? null,
      rentalDays: book.rentalDays ?? 14,
      pages: book.pages,
      // The original eight demo books keep their old rating and "new" badge; others start unrated.
      rating: ORIGINAL_DEMO_IDS.has(book.id) ? 4.8 : 0,
      isNew: book.isNew ?? ORIGINAL_DEMO_IDS.has(book.id),
      isAdult: book.isAdult ?? false,
      accessType: book.accessType ?? 'FREE',
      status: 'PUBLISHED',
    }));
    form.set('cover', new Blob([cover], { type: 'image/jpeg' }), `pg${book.id}.jpg`);
    form.set('epub', new Blob([epub], { type: 'application/epub+zip' }), `pg${book.id}.epub`);
    await request('/admin/books-with-files', { token: login.token, method: 'POST', body: form });
    console.log(`PASS ${book.title}`);
  }
})();
