// Admin UI scenarios in a real browser. Needs the API and the admin dev server running.
// Uses the local seed admin from server/.env.example.
const assert = require('node:assert/strict');
const path = require('node:path');
const { chromium } = require('playwright');

const adminUrl = process.env.KITAPP_ADMIN_URL || 'http://127.0.0.1:5173';
const bravePath = process.env.BRAVE_PATH || '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';
const email = process.env.ADMIN_EMAIL || 'admin@kitapp.kg';
const password = process.env.ADMIN_PASSWORD || 'Kitapp123!';
const fixtures = path.join(__dirname, 'fixtures');

(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: bravePath });
  const page = await browser.newPage({ viewport: { width: 1440, height: 950 } });
  page.setDefaultTimeout(10000);
  const errors = [];
  page.on('console', (message) => {
    if (message.type() === 'error' && !message.text().includes('404 (Not Found)')) errors.push(message.text());
  });
  const drawer = page.locator('.drawer');
  const dialog = page.locator('.dialog');
  const toast = (text) => page.locator('#toast.visible', { hasText: text }).waitFor();

  try {
    await page.goto(adminUrl, { waitUntil: 'networkidle' });
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Сырсөз').fill(password);
    await page.getByRole('button', { name: 'Кирүү', exact: true }).click();
    await page.getByRole('heading', { name: 'Көңүл буруу керек' }).waitFor();
    await page.getByText('Жалпы киреше', { exact: true }).waitFor();
    console.log('PASS login and home page');

    const suffix = Date.now();
    const title = `QA китеп ${suffix}`;
    const author = `QA автор ${suffix}`;
    await page.getByRole('link', { name: 'Китептер' }).click();
    await page.getByRole('button', { name: 'Китеп кошуу' }).click();
    await drawer.getByRole('heading', { name: 'Жаңы китеп' }).waitFor();
    await drawer.getByLabel('Аталышы').fill(title);
    await drawer.locator('select').first().selectOption('__new');
    await drawer.getByLabel('Жаңы автордун аты').fill(author);
    await drawer.getByLabel('Сүрөттөмө').fill('QA сыноо китеби');
    await drawer.getByRole('button', { name: 'Сактоо' }).click();
    await drawer.getByText('мукаба жана EPUB файлын тандаңыз', { exact: false }).waitFor();
    await drawer.locator('input[type=file]').nth(0).setInputFiles(path.join(fixtures, 'cover.png'));
    await drawer.locator('input[type=file]').nth(1).setInputFiles(path.join(fixtures, 'test.epub'));
    await drawer.getByRole('button', { name: 'Сактоо' }).click();
    await toast('кошулду');
    await page.getByPlaceholder('Аталышы же автору').fill(title);
    const row = page.locator('tbody tr', { hasText: title });
    await row.getByText('Долбоор').waitFor();
    assert.ok((await row.textContent()).includes(author), 'new author is set on the book');
    console.log('PASS create a draft book with a new author and files');

    await row.click();
    await drawer.getByRole('radio', { name: 'Ижара гана' }).click();
    await drawer.getByRole('button', { name: 'Сактоо' }).click();
    await toast('сакталды');
    await row.getByText('Ижара 69 сом / 14 күн').waitFor();
    console.log('PASS switch a book to rental only');

    await row.click();
    await drawer.getByRole('button', { name: 'Архивге жиберүү' }).click();
    await dialog.getByRole('button', { name: 'Архивге жиберүү' }).click();
    await toast('архивге жиберилди');
    await row.waitFor({ state: 'detached' });
    console.log('PASS archive a book');

    await page.getByRole('link', { name: 'Авторлор жана жанрлар' }).click();
    const renamed = `${author} өзгөргөн`;
    await page.getByPlaceholder('Авторлор ичинен издөө').fill(author);
    await page.getByRole('button', { name: `${author}: атын өзгөртүү` }).click();
    const editInput = page.locator('.row input');
    await editInput.fill(renamed);
    await page.locator('.row').getByRole('button', { name: 'Сактоо' }).click();
    await page.getByText(renamed, { exact: true }).waitFor();
    await page.getByRole('button', { name: `${renamed}: өчүрүү` }).click();
    await dialog.getByRole('button', { name: 'Өчүрүү' }).click();
    await toast('өчүрүлдү');
    console.log('PASS rename and delete an author');

    await page.getByRole('link', { name: 'Окурмандар' }).click();
    await page.getByRole('radio', { name: /Активдүү/ }).click();
    const reader = page.locator('tbody tr').first();
    const readerPhone = (await reader.locator('td').first().locator('strong').textContent()).trim();
    await reader.getByRole('button', { name: 'Бөгөттөө' }).click();
    await dialog.getByLabel('Себеби').fill('QA сыноо');
    await dialog.getByRole('button', { name: 'Бөгөттөө' }).click();
    await toast('бөгөттөлдү');
    await page.getByRole('radio', { name: /Бөгөттөлгөн/ }).click();
    const blocked = page.locator('tbody tr', { hasText: readerPhone });
    await blocked.getByText('QA сыноо').waitFor();
    await blocked.getByRole('button', { name: 'Бөгөттөн чыгаруу' }).click();
    await dialog.getByRole('button', { name: 'Бөгөттөн чыгаруу' }).click();
    await toast('бөгөттөн чыгарылды');
    console.log('PASS block a reader with a reason and unblock');

    await page.getByRole('link', { name: 'Төлөмдөр' }).click();
    await page.getByRole('radio', { name: /Ижаралар/ }).click();
    await page.getByText('Төлөнгөнү:').waitFor();
    console.log('PASS payments page');

    await page.getByRole('link', { name: 'Отчёт' }).click();
    await page.getByRole('button', { name: 'Өткөн ай' }).click();
    await page.getByText('Сатылган аталыштар').waitFor();
    console.log('PASS sales report presets');

    await page.getByRole('link', { name: 'Аракеттер журналы' }).click();
    await page.getByText(`«${title}»`).first().waitFor();
    assert.equal(errors.length, 0, `browser console errors: ${errors.join('; ')}`);
    console.log('PASS audit log and clean browser console');
    console.log('PASS all admin UI scenarios');
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
