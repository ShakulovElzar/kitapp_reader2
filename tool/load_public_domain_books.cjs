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
];

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
    const [epub, cover] = await Promise.all([download(epubUrl), download(coverUrl)]);
    const form = new FormData();
    form.set('data', JSON.stringify({
      title: book.title,
      slug: book.slug,
      description: `${book.description}\n\nБулак: Project Gutenberg, eBook №${book.id}. Коомдук домен (АКШ).`,
      authorId: author.id,
      categoryId: category.id,
      price: 0,
      pages: book.pages,
      rating: 4.8,
      isNew: true,
      accessType: 'FREE',
      status: 'PUBLISHED',
    }));
    form.set('cover', new Blob([cover], { type: 'image/jpeg' }), `pg${book.id}.jpg`);
    form.set('epub', new Blob([epub], { type: 'application/epub+zip' }), `pg${book.id}.epub`);
    await request('/admin/books-with-files', { token: login.token, method: 'POST', body: form });
    console.log(`PASS ${book.title}`);
  }
})();
