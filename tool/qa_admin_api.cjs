const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');

const baseUrl = process.env.KITAPP_API_URL || 'http://127.0.0.1:3000/api';

async function request(path, { token, ...init } = {}) {
  const headers = new Headers(init.headers);
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (init.body && !(init.body instanceof FormData)) headers.set('Content-Type', 'application/json');
  const response = await fetch(`${baseUrl}${path}`, { ...init, headers });
  const body = await response.json().catch(() => null);
  assert.ok(response.ok, `${init.method || 'GET'} ${path}: ${JSON.stringify(body)}`);
  return body;
}

async function rejected(path, expectedStatus, init = {}) {
  const headers = new Headers(init.headers);
  if (init.token) headers.set('Authorization', `Bearer ${init.token}`);
  if (init.body && !(init.body instanceof FormData)) headers.set('Content-Type', 'application/json');
  const response = await fetch(`${baseUrl}${path}`, { ...init, headers });
  const body = await response.json().catch(() => null);
  assert.equal(response.status, expectedStatus, `${init.method || 'GET'} ${path}: ${JSON.stringify(body)}`);
  return body;
}

(async () => {
  const suffix = Date.now().toString(36);
  const phone = `0555${String(Date.now()).slice(-6)}`;
  const login = await request('/auth/admin/login', {
    method: 'POST',
    body: JSON.stringify({ email: 'admin@kitapp.kg', password: 'Kitapp123!' }),
  });
  assert.ok(login.token);
  console.log('PASS admin login');

  const dashboard = await request('/admin/dashboard', { token: login.token });
  assert.ok(dashboard.books >= 16);
  assert.ok(dashboard.sales >= 5);
  console.log('PASS dashboard aggregates');

  const report = await request('/admin/reports/sales?from=2020-01-01&to=2030-12-31', {
    token: login.token,
  });
  assert.ok(report.totalQuantity >= 5);
  assert.ok(report.items.every((item) => item.title && item.author));
  assert.equal(report.timeZone, 'Asia/Bishkek');
  assert.equal(report.totalRevenue, report.salesRevenue + report.rentalRevenue);
  console.log('PASS book and author sales report');

  if (process.env.KITAPP_QA_EDITOR_EMAIL) {
    const editor = await request('/auth/admin/login', {
      method: 'POST',
      body: JSON.stringify({ email: process.env.KITAPP_QA_EDITOR_EMAIL, password: process.env.KITAPP_QA_EDITOR_PASSWORD }),
    });
    const editorDashboard = await request('/admin/dashboard', { token: editor.token });
    assert.equal(editorDashboard.revenue, undefined, 'editors must not see revenue');
    await request('/admin/books', { token: editor.token });
    for (const path of ['/admin/readers', '/admin/purchases', '/admin/reports/sales', '/admin/audit-logs']) {
      await rejected(path, 403, { token: editor.token });
    }
    console.log('PASS editors manage content only');
  }

  const otp = await request('/auth/phone/request-otp', {
    method: 'POST',
    body: JSON.stringify({ phone }),
  });
  assert.equal(otp.developmentCode, '111111');
  await rejected('/auth/phone/verify-otp', 401, {
    method: 'POST',
    body: JSON.stringify({ phone, code: '000000' }),
  });
  const reader = await request('/auth/phone/verify-otp', {
    method: 'POST',
    body: JSON.stringify({ phone, code: '111111' }),
  });
  assert.ok(reader.token);
  console.log('PASS phone-only reader authentication');

  const catalog = await request('/catalog/books');
  assert.ok(Array.isArray(catalog));
  assert.ok(catalog.every((item) => item.coverUrl && item.epubKey));
  console.log('PASS catalog excludes incomplete published books');

  let author;
  let category;
  let book;
  try {
    author = await request('/admin/authors', {
      token: login.token,
      method: 'POST',
      body: JSON.stringify({ name: `QA Автор ${suffix}` }),
    });
    category = await request('/admin/categories', {
      token: login.token,
      method: 'POST',
      body: JSON.stringify({ name: `QA Категория ${suffix}`, slug: `qa-${suffix}` }),
    });
    book = await request('/admin/books', {
      token: login.token,
      method: 'POST',
      body: JSON.stringify({
        title: `QA Китеп ${suffix}`,
        slug: `qa-book-${suffix}`,
        description: 'Убактылуу QA китеби',
        authorId: author.id,
        categoryId: category.id,
        price: 100,
        rentalPrice: 49,
        rentalDays: 14,
        pages: 100,
        status: 'DRAFT',
      }),
    });
    const publishWithoutFiles = await fetch(`${baseUrl}/admin/books/${book.id}`, {
      headers: {
        Authorization: `Bearer ${login.token}`,
        'Content-Type': 'application/json',
      },
      token: login.token,
      method: 'PATCH',
      body: JSON.stringify({ status: 'PUBLISHED' }),
    });
    assert.equal(publishWithoutFiles.status, 400);
    console.log('PASS publishing without files is rejected');

    await request(`/admin/books/${book.id}`, { token: login.token, method: 'DELETE' });
    book = undefined;

    const coverPath = path.resolve(__dirname, 'fixtures/cover.png');
    const epubPath = process.env.KITAPP_QA_EPUB
      ? path.resolve(process.env.KITAPP_QA_EPUB)
      : path.resolve(__dirname, 'fixtures/test.epub');
    const form = new FormData();
    form.set('data', JSON.stringify({
      title: `QA EPUB ${suffix}`,
      slug: `qa-epub-${suffix}`,
      description: 'EPUB менен атомардык түзүлгөн QA китеби',
      authorId: author.id,
      categoryId: category.id,
      price: 0,
      pages: 100,
      accessType: 'FREE',
      status: 'PUBLISHED',
    }));
    form.set('cover', new Blob([await fs.readFile(coverPath)], { type: 'image/png' }), 'cover.png');
    form.set('epub', new Blob([await fs.readFile(epubPath)], { type: 'application/epub+zip' }), 'book.epub');
    book = await request('/admin/books-with-files', {
      token: login.token,
      method: 'POST',
      body: form,
    });
    assert.equal(book.status, 'PUBLISHED');
    assert.ok(book.coverKey && book.epubKey);
    const catalogWithBook = await request('/catalog/books');
    assert.ok(catalogWithBook.some((item) => item.id === book.id));
    const file = await request(`/reader/books/${book.id}/file`, { token: reader.token });
    const libraryAfterOpen = await request('/reader/library', { token: reader.token });
    assert.ok(libraryAfterOpen.some((item) => item.id === book.id), 'opened free book joins the library');
    const manifest = await fetch(file.manifestUrl).then((response) => {
      assert.ok(response.ok, `GET manifest: ${response.status}`);
      return response.json();
    });
    assert.ok(manifest.readingOrder.length > 0);
    assert.equal(manifest.resources.length, manifest.readingOrder.length);
    assert.ok(manifest.toc.length > 0);
    assert.ok(
      Array.isArray(manifest.pageList) && manifest.pageList.length > 1,
      'EPUB without page markers must receive a stable generated page list',
    );
    assert.equal(manifest.metadata.numberOfPages, manifest.pageList.length);
    const positionsLink = manifest.links.find((link) =>
      (Array.isArray(link.rel) ? link.rel : [link.rel]).includes('positions'),
    );
    assert.ok(positionsLink, 'manifest must advertise the generated positions list');
    const positions = await fetch(new URL(positionsLink.href, file.manifestUrl)).then((response) => {
      assert.ok(response.ok, `GET positions: ${response.status}`);
      return response.json();
    });
    assert.equal(positions.metadata.numberOfItems, manifest.pageList.length);
    // The paginated reader needs `total`, and position hrefs without #fragments.
    assert.equal(positions.total, manifest.pageList.length);
    assert.deepEqual(
      positions.positions,
      manifest.pageList.map((page) => ({ ...page, href: page.href.split('#')[0] })),
    );
    assert.equal(manifest.metadata.conformsTo, 'https://readium.org/webpub-manifest/profiles/epub');
    assert.ok(manifest.metadata.identifier, 'each book needs its own identifier');
    const unsigned = file.manifestUrl.replace(/\/files\/s\/[^/]+\//, '/files/');
    assert.notEqual((await fetch(unsigned)).status, 200, 'book files must not be public');
    const tampered = file.manifestUrl.replace(/\/files\/s\/(\d+)\./, '/files/s/$1.x');
    assert.equal((await fetch(tampered)).status, 403, 'tampered links must be rejected');
    const generatedMarker = manifest.pageList.find((locator) =>
      locator.locations?.fragments?.[0]?.startsWith('kitapp-page-'),
    );
    assert.ok(generatedMarker, 'generated page locators must point to stable XHTML markers');
    const generatedDocument = await fetch(
      new URL(generatedMarker.href.split('#')[0], file.manifestUrl),
    ).then((response) => response.text());
    assert.match(generatedDocument, /role=["']doc-pagebreak["']/);
    console.log('PASS atomic EPUB upload, extraction and manifest');

    const duplicate = new FormData();
    duplicate.set('data', JSON.stringify({
      title: `QA EPUB duplicate ${suffix}`,
      slug: `qa-epub-${suffix}`,
      description: 'Кайталанган URL белгиси кабыл алынбашы керек',
      authorId: author.id,
      categoryId: category.id,
      price: 0,
      pages: 10,
      accessType: 'FREE',
      status: 'PUBLISHED',
    }));
    duplicate.set('cover', new Blob([await fs.readFile(coverPath)], { type: 'image/png' }), 'cover.png');
    duplicate.set('epub', new Blob([await fs.readFile(epubPath)], { type: 'application/epub+zip' }), 'book.epub');
    await rejected('/admin/books-with-files', 409, { token: login.token, method: 'POST', body: duplicate });
    const duplicateMatches = (await request('/admin/books', { token: login.token }))
      .filter((item) => item.slug === `qa-epub-${suffix}`);
    assert.equal(duplicateMatches.length, 1);
    console.log('PASS duplicate slug does not leave a partial book');

    const invalid = new FormData();
    invalid.set('data', JSON.stringify({
      title: `QA invalid ${suffix}`,
      slug: `qa-invalid-${suffix}`,
      description: 'Жараксыз EPUB кабыл алынбашы керек',
      authorId: author.id,
      categoryId: category.id,
      price: 0,
      pages: 10,
      accessType: 'FREE',
      status: 'PUBLISHED',
    }));
    invalid.set('cover', new Blob([await fs.readFile(coverPath)], { type: 'image/png' }), 'cover.png');
    invalid.set('epub', new Blob([Buffer.from('not-an-epub')], { type: 'application/epub+zip' }), 'invalid.epub');
    await rejected('/admin/books-with-files', 400, { token: login.token, method: 'POST', body: invalid });
    assert.ok(!(await request('/admin/books', { token: login.token })).some((item) => item.slug === `qa-invalid-${suffix}`));
    console.log('PASS invalid EPUB leaves no partial book');

    await request('/reader/progress', {
      token: reader.token,
      method: 'POST',
      body: JSON.stringify({
        bookId: book.id,
        progression: 0.25,
        activeSeconds: 120,
        locator: { href: manifest.readingOrder[0].href, type: 'application/xhtml+xml' },
      }),
    });
    const recent = await request('/reader/recent', { token: reader.token });
    assert.equal(recent[0].book.id, book.id);
    assert.equal(recent[0].activeSeconds, 120);
    console.log('PASS two-minute reading appears in last-three list');

    await request(`/admin/books/${book.id}`, { token: login.token, method: 'DELETE' });
    const libraryAfterArchive = await request('/reader/library', { token: reader.token });
    assert.ok(!libraryAfterArchive.some((item) => item.id === book.id));
    book = undefined;
    console.log('PASS free book joins the library when opened and leaves when archived');

    const paidBook = async (accessType, price, rentalPrice) => {
      const data = new FormData();
      data.set('data', JSON.stringify({
        title: `QA ${accessType} ${suffix}`,
        slug: `qa-${accessType.toLowerCase()}-${suffix}`,
        description: 'QA access rules',
        authorId: author.id,
        categoryId: category.id,
        price,
        rentalPrice,
        rentalDays: 7,
        pages: 10,
        accessType,
        status: 'PUBLISHED',
      }));
      data.set('cover', new Blob([await fs.readFile(coverPath)], { type: 'image/png' }), 'cover.png');
      data.set('epub', new Blob([await fs.readFile(epubPath)], { type: 'application/epub+zip' }), 'book.epub');
      return data;
    };
    await rejected('/admin/books-with-files', 400, { token: login.token, method: 'POST', body: await paidBook('PURCHASE', 0, null) });
    const owned = await request('/admin/books-with-files', { token: login.token, method: 'POST', body: await paidBook('PURCHASE', 150, 30) });
    const rentalOnly = await request('/admin/books-with-files', { token: login.token, method: 'POST', body: await paidBook('RENTAL', 200, 40) });
    try {
      await rejected('/reader/purchases', 400, { token: reader.token, method: 'POST', body: JSON.stringify({ bookId: rentalOnly.id }) });
      await request('/reader/rentals', { token: reader.token, method: 'POST', body: JSON.stringify({ bookId: rentalOnly.id }) });
      await request('/reader/purchases', { token: reader.token, method: 'POST', body: JSON.stringify({ bookId: owned.id }) });
      await request(`/admin/books/${owned.id}`, { token: login.token, method: 'DELETE' });
      const libraryAfterPaidArchive = await request('/reader/library', { token: reader.token });
      assert.ok(libraryAfterPaidArchive.some((item) => item.id === owned.id), 'bought book survives archiving');
      assert.ok(libraryAfterPaidArchive.some((item) => item.id === rentalOnly.id && item.readerAccess === 'RENTAL'));
      await request(`/reader/books/${owned.id}/file`, { token: reader.token });
      console.log('PASS strict access rules; bought books survive archiving');
    } finally {
      await request(`/admin/books/${rentalOnly.id}`, { token: login.token, method: 'DELETE' }).catch(() => {});
      await request(`/admin/books/${owned.id}`, { token: login.token, method: 'DELETE' }).catch(() => {});
    }
  } finally {
    if (book) await request(`/admin/books/${book.id}`, { token: login.token, method: 'DELETE' });
    if (author) await request(`/admin/authors/${author.id}`, { token: login.token, method: 'DELETE' });
    if (category) await request(`/admin/categories/${category.id}`, { token: login.token, method: 'DELETE' });
  }

  console.log('PASS all admin API scenarios');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
