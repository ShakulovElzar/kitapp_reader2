const assert = require('node:assert/strict');

const baseUrl = process.env.KITAPP_API_URL || 'http://127.0.0.1:3000/api';

async function request(path, { token, ...init } = {}) {
  const headers = new Headers(init.headers);
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (init.body) headers.set('Content-Type', 'application/json');
  const response = await fetch(`${baseUrl}${path}`, { ...init, headers });
  const body = await response.json().catch(() => null);
  assert.ok(response.ok, `${init.method || 'GET'} ${path}: ${JSON.stringify(body)}`);
  return body;
}

(async () => {
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
  console.log('PASS book and author sales report');

  const otp = await request('/auth/phone/request-otp', {
    method: 'POST',
    body: JSON.stringify({ phone: '0555123456' }),
  });
  assert.equal(otp.developmentCode, '111111');
  const reader = await request('/auth/phone/verify-otp', {
    method: 'POST',
    body: JSON.stringify({ phone: '0555123456', code: '111111' }),
  });
  assert.ok(reader.token);
  console.log('PASS phone-only reader authentication');

  const catalog = await request('/catalog/books');
  assert.ok(catalog.length >= 16);
  console.log('PASS published catalog');

  const suffix = Date.now().toString(36);
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
    const published = await request(`/admin/books/${book.id}`, {
      token: login.token,
      method: 'PATCH',
      body: JSON.stringify({ status: 'PUBLISHED' }),
    });
    assert.equal(published.status, 'PUBLISHED');
    console.log('PASS catalog CRUD and publishing');
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
