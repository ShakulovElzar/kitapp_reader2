const assert = require('node:assert/strict');
const { readFile } = require('node:fs/promises');
const { chromium } = require('playwright');

const appUrl = process.env.KITAPP_URL || 'http://127.0.0.1:8083';
const apiUrl = process.env.KITAPP_API_URL || 'http://127.0.0.1:3000/api';
const bravePath =
  process.env.BRAVE_PATH ||
  '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';

async function request(path, { token, body, ...init } = {}) {
  const headers = new Headers(init.headers);
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (body && !(body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
    body = JSON.stringify(body);
  }
  const response = await fetch(`${apiUrl}${path}`, { ...init, headers, body });
  const value = await response.json().catch(() => null);
  if (!response.ok) {
    throw new Error(`${init.method || 'GET'} ${path}: ${JSON.stringify(value)}`);
  }
  return value;
}

async function createBookFixture({ token, authorId, categoryId, data }) {
  const files = new FormData();
  files.append('data', JSON.stringify(data));
  files.append(
    'cover',
    new Blob([await readFile('web/icons/Icon-192.png')], { type: 'image/png' }),
    'cover.png',
  );
  files.append(
    'epub',
    new Blob([await readFile('assets/books/test.epub')], {
      type: 'application/epub+zip',
    }),
    'book.epub',
  );
  return request('/admin/books-with-files', {
    token,
    method: 'POST',
    body: files,
  });
}

async function enableFlutterAccessibility(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) {
    await placeholder.evaluate((element) => element.click());
    await page.waitForTimeout(150);
  }
}

async function back(page) {
  const button = page.getByRole('button', { name: /Back|Артка/ }).first();
  assert.ok(await button.count(), 'current page must expose a back button');
  await button.click();
  await page.waitForTimeout(250);
}

async function openCatalogSearch(page) {
  const title = page.getByText('Жаңы болуп чыкты', { exact: true });
  await title.waitFor();
  await page.getByRole('button', { name: 'Издөө', exact: true }).click();
  await page.getByText('Бардык китептер', { exact: true }).waitFor();
  return page.getByRole('textbox', { name: /Китеп же авторду издеңиз/ });
}

async function searchCatalog(page, query) {
  const field = await openCatalogSearch(page);
  await field.fill(query);
  await page.waitForTimeout(250);
  return field;
}

async function returnToCatalog(page) {
  while (!(await page.getByText('Жаңы болуп чыкты', { exact: true }).count())) {
    await back(page);
  }
}

(async () => {
  const suffix = Date.now().toString(36);
  const titles = {
    purchase: `QA Сатып алуу ${suffix}`,
    rental: `QA Ижара ${suffix}`,
    adult: `QA 18+ ${suffix}`,
  };
  const createdBooks = [];
  const failures = [];
  const passes = [];

  async function check(name, action) {
    try {
      await action();
      passes.push(name);
      console.log(`PASS ${name}`);
    } catch (error) {
      failures.push(`${name}: ${error.message}`);
      console.error(`FAIL ${name}: ${error.message}`);
    }
  }

  const login = await request('/auth/admin/login', {
    method: 'POST',
    body: { email: 'admin@kitapp.kg', password: 'Kitapp123!' },
  });
  const [authors, categories] = await Promise.all([
    request('/admin/authors', { token: login.token }),
    request('/admin/categories', { token: login.token }),
  ]);
  const authorId = authors[0].id;
  const categoryId = categories.find((item) => item.name === 'Роман')?.id || categories[0].id;
  const common = {
    description: 'QA үчүн убактылуу китеп',
    authorId,
    categoryId,
    pages: 120,
    rating: 4.2,
    isNew: true,
    status: 'PUBLISHED',
  };

  try {
    createdBooks.push(
      await createBookFixture({
        token: login.token,
        authorId,
        categoryId,
        data: {
          ...common,
          title: titles.purchase,
          slug: `qa-purchase-${suffix}`,
          price: 321,
          accessType: 'PURCHASE',
          isAdult: false,
        },
      }),
      await createBookFixture({
        token: login.token,
        authorId,
        categoryId,
        data: {
          ...common,
          title: titles.rental,
          slug: `qa-rental-${suffix}`,
          price: 499,
          rentalPrice: 77,
          rentalDays: 3,
          accessType: 'RENTAL',
          isAdult: false,
        },
      }),
      await createBookFixture({
        token: login.token,
        authorId,
        categoryId,
        data: {
          ...common,
          title: titles.adult,
          slug: `qa-adult-${suffix}`,
          price: 0,
          accessType: 'FREE',
          isAdult: true,
        },
      }),
    );

    const browser = await chromium.launch({
      headless: true,
      executablePath: bravePath,
    });
    const context = await browser.newContext({ viewport: { width: 480, height: 900 } });
    await context.grantPermissions(['clipboard-read', 'clipboard-write'], {
      origin: appUrl,
    });
    let page = await context.newPage();
    page.setDefaultTimeout(6000);
    const consoleErrors = [];
    page.on('console', (message) => {
      if (message.type() === 'error') consoleErrors.push(message.text());
    });
    page.on('pageerror', (error) => consoleErrors.push(error.message));

    try {
      await page.goto(appUrl, { waitUntil: 'networkidle', timeout: 30000 });
      await page.waitForTimeout(2500);
      await enableFlutterAccessibility(page);

      const phone = `0555${String(Date.now()).slice(-6)}`;
      let signedInPhone = phone;
      await check('auth rejects an invalid OTP', async () => {
        await page.getByRole('textbox', { name: /Телефон номери/ }).fill(phone);
        await page.getByRole('button', { name: 'Код алуу', exact: true }).click();
        await page.getByRole('textbox', { name: /6 орундуу код/ }).fill('000000');
        await page.getByRole('button', { name: 'Кирүү', exact: true }).click();
        await page.getByText('Код туура эмес же мөөнөтү бүттү', { exact: true }).waitFor();
      });

      await check('auth accepts the valid OTP', async () => {
        await page.close();
        page = await context.newPage();
        page.setDefaultTimeout(6000);
        page.on('console', (message) => {
          if (message.type() === 'error') consoleErrors.push(message.text());
        });
        page.on('pageerror', (error) => consoleErrors.push(error.message));
        await page.goto(appUrl, { waitUntil: 'networkidle', timeout: 30000 });
        await page.waitForTimeout(1200);
        await enableFlutterAccessibility(page);
        const validPhone = `0556${String(Date.now()).slice(-6)}`;
        signedInPhone = validPhone;
        await page.getByRole('textbox', { name: /Телефон номери/ }).fill(validPhone);
        await page.getByRole('button', { name: 'Код алуу', exact: true }).click();
        await page.getByRole('textbox', { name: /6 орундуу код/ }).fill('111111');
        await page.getByRole('button', { name: 'Кирүү', exact: true }).click();
        await page.getByText('Жаңы болуп чыкты', { exact: true }).waitFor({ timeout: 15000 });
      });

      await check('catalog opens the complete searchable list', async () => {
        await openCatalogSearch(page);
        await page.getByText('Бардык китептер', { exact: true }).waitFor();
        await back(page);
        await page.getByText('Жаңы болуп чыкты', { exact: true }).waitFor();
      });

      await check('catalog data covers all server categories', async () => {
        const serverCategories = await request('/catalog/categories');
        const catalog = await request('/catalog/books');
        const exposed = new Set(catalog.map((book) => book.category.name));
        const missing = serverCategories
          .map((category) => category.name)
          .filter((name) => !exposed.has(name));
        assert.deepEqual(missing, [], `missing categories: ${missing.join(', ')}`);
      });

      await check('catalog search finds title and author and shows empty outcome', async () => {
        let field = await openCatalogSearch(page);
        await field.fill(titles.purchase);
        await page.getByText(titles.purchase, { exact: true }).waitFor();
        await field.fill(authors[0].name);
        assert.ok((await page.getByText(authors[0].name, { exact: true }).count()) > 0);
        await field.fill(`missing-${suffix}`);
        await page.getByText('Китеп табылган жок', { exact: true }).waitFor();
        await back(page);
      });

      await check('catalog filters apply and clear', async () => {
        const field = await openCatalogSearch(page);
        await page.getByRole('button', { name: 'Фильтр', exact: true }).click();
        await page.getByText('Баанын диапазону', { exact: true }).waitFor();
        await page.getByText('Акысыз', { exact: true }).click();
        await page.getByRole('button', { name: 'Колдонуу', exact: true }).click();
        assert.equal(await page.getByText(titles.purchase, { exact: true }).count(), 0);

        await page.getByRole('button', { name: 'Фильтр', exact: true }).click();
        await page.getByRole('button', { name: 'Тазалоо', exact: true }).click();
        await page.getByRole('button', { name: 'Колдонуу', exact: true }).click();
        await field.fill(titles.purchase);
        await page.getByText(titles.purchase, { exact: true }).waitFor();
        await back(page);
      });

      await check('book card opens and share copies a link', async () => {
        await searchCatalog(page, titles.purchase);
        await page.getByText(titles.purchase, { exact: true }).click();
        await page.getByText('Кыскача маалымат', { exact: true }).waitFor();
        await page.evaluate(() => navigator.clipboard.writeText('qa-sentinel'));
        await page.getByRole('button', { name: 'Бөлүшүү', exact: true }).click();
        await page.getByText('Китептин шилтемеси көчүрүлдү', { exact: true }).waitFor();
        const clipboard = await page.evaluate(() => navigator.clipboard.readText());
        assert.notEqual(clipboard, 'qa-sentinel', 'share reports success without copying');
        assert.match(clipboard, /qa-purchase|QA Сатып алуу|http/i);
        await returnToCatalog(page);
      });

      await check('free book can be added and then read', async () => {
        await searchCatalog(page, 'Казына аралы');
        await page.getByText('Казына аралы', { exact: true }).click();
        const add = page.getByRole('button', { name: 'Китепканага кошуу', exact: true });
        await add.waitFor();
        await add.click();
        await page.getByRole('button', { name: 'Ооба', exact: true }).click();
        await page.getByText('Китеп китепканага кошулду', { exact: true }).waitFor();
        await page.getByRole('button', { name: /Окууну (баштоо|улантуу)/ }).waitFor();
        await returnToCatalog(page);
      });

      await check('purchase completes from the book card', async () => {
        await searchCatalog(page, titles.purchase);
        await page.getByText(titles.purchase, { exact: true }).click();
        const buy = page.getByRole('button', { name: /321 сомго сатып алуу/ });
        await buy.waitFor();
        await buy.click();
        await page.getByRole('button', { name: 'Ооба', exact: true }).click();
        await page.getByText('Китеп китепканага кошулду', { exact: true }).waitFor();
        await page.getByRole('button', { name: /Окууну (баштоо|улантуу)/ }).waitFor();
        await returnToCatalog(page);
      });

      await check('rental completes and shows its term', async () => {
        await searchCatalog(page, titles.rental);
        await page.getByText(titles.rental, { exact: true }).click();
        const rent = page.getByRole('button', { name: /3 күнгө 77 сомго ижарага алуу/ });
        await rent.waitFor();
        await rent.click();
        await page.getByRole('button', { name: 'Ижарага алуу', exact: true }).click();
        await page.getByText('Китеп 3 күнгө ижарага алынды', { exact: true }).waitFor();
        await page.getByText(/Ижара мөөнөтү:/).waitFor();
        await page.getByRole('button', { name: /Окууну (баштоо|улантуу)/ }).waitFor();
        await returnToCatalog(page);
      });

      await check('library search opens a book card', async () => {
        await page.getByText('Башкы китептер', { exact: true }).click();
        await page.getByText('Менин китептерим', { exact: true }).waitFor();
        await page.getByRole('button', { name: 'Издөө', exact: true }).click();
        const field = page.getByRole('textbox', { name: /Китептен издөө/ });
        await field.fill('Казына аралы');
        await page.getByText('Казына аралы', { exact: true }).click();
        await page.getByText('Кыскача маалымат', { exact: true }).waitFor();
        await back(page);
        await page.getByText('Менин китептерим', { exact: true }).waitFor();
      });

      await check('library card menu opens details and share outcome', async () => {
        const menu = page.getByRole('button', { name: /Show menu|Меню/ }).first();
        await menu.waitFor();
        await menu.click();
        await page.getByText('Китеп жөнүндө', { exact: true }).click();
        await page.getByText('Кыскача маалымат', { exact: true }).waitFor();
        await back(page);

        await page.getByRole('button', { name: /Show menu|Меню/ }).first().click();
        await page.getByText('Бөлүшүү', { exact: true }).click();
        await page.getByText('Китептин шилтемеси көчүрүлдү', { exact: true }).waitFor();
      });

      await check('library completed filter has a stable empty outcome', async () => {
        await page.getByText('Окулуп бүттү', { exact: true }).click();
        await page.getByText('Китепканаңыз азырынча бош', { exact: true }).waitFor();
        await page.getByText('Баары', { exact: true }).click();
        await page.getByText('Менин китептерим', { exact: true }).waitFor();
      });

      await check('profile information pages all open and close', async () => {
        await page.getByText('Профиль', { exact: true }).last().click();
        for (const title of [
          'Сатып алуулар',
          'Активдүү ижаралар',
          'Биз менен байланышуу',
          'Колдонмо жөнүндө',
        ]) {
          await page.getByText(title, { exact: true }).first().click();
          await page.getByText(title, { exact: true }).last().waitFor();
          await back(page);
          await page.getByText('18+ мазмунду көрсөтүү', { exact: true }).waitFor();
        }
      });

      await check('18+ toggle hides and reveals adult catalog content', async () => {
        const toggle = page.getByRole('switch', { name: /18\+ мазмунду көрсөтүү/ });
        assert.equal(await toggle.getAttribute('aria-checked'), 'false');
        await toggle.click();
        assert.equal(await toggle.getAttribute('aria-checked'), 'true');
        await page.getByText('Категориялар', { exact: true }).click();
        await searchCatalog(page, titles.adult);
        await page.getByText(titles.adult, { exact: true }).waitFor();
        await returnToCatalog(page);

        await page.getByText('Профиль', { exact: true }).last().click();
        await page.getByRole('switch', { name: /18\+ мазмунду көрсөтүү/ }).click();
        await page.getByText('Категориялар', { exact: true }).click();
        await searchCatalog(page, titles.adult);
        await page.getByText('Китеп табылган жок', { exact: true }).waitFor();
        await returnToCatalog(page);
      });

      await check('logout cancel keeps session and confirm clears it', async () => {
        await page.getByText('Профиль', { exact: true }).last().click();
        await page.getByRole('button', { name: 'Чыгуу', exact: true }).click();
        await page.getByRole('button', { name: 'Жок', exact: true }).click();
        await page.getByText(signedInPhone, { exact: true }).waitFor();

        await page.getByRole('button', { name: 'Чыгуу', exact: true }).click();
        await page.getByRole('button', { name: 'Ооба', exact: true }).click();
        await page.getByRole('button', { name: 'Код алуу', exact: true }).waitFor();
        await page.reload({ waitUntil: 'networkidle' });
        await page.waitForTimeout(1200);
        await enableFlutterAccessibility(page);
        await page.getByRole('button', { name: 'Код алуу', exact: true }).waitFor();
      });

      await check('user flow has no browser console errors', async () => {
        assert.deepEqual(consoleErrors, [], consoleErrors.join('\n'));
      });

      if (failures.length) {
        await page.screenshot({ path: '/tmp/kitapp-user-flow-failure.png', fullPage: true });
      }
    } finally {
      await browser.close();
    }
  } finally {
    await Promise.all(
      createdBooks.map((book) =>
        request(`/admin/books/${book.id}`, {
          token: login.token,
          method: 'DELETE',
        }).catch(() => null),
      ),
    );
  }

  console.log(`\nRESULT ${passes.length} passed, ${failures.length} failed`);
  for (const failure of failures) console.error(`- ${failure}`);
  if (failures.length) process.exitCode = 1;
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
