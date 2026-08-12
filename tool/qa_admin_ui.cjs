const assert = require('node:assert/strict');
const { chromium } = require('playwright');

const adminUrl = process.env.KITAPP_ADMIN_URL || 'http://127.0.0.1:5173';
const bravePath = process.env.BRAVE_PATH || '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';

(async () => {
  const browser = await chromium.launch({ headless: true, executablePath: bravePath });
  const page = await browser.newPage({ viewport: { width: 1440, height: 950 } });
  page.setDefaultTimeout(8000);
  const errors = [];
  page.on('console', (message) => {
    if (message.type() === 'error' && !message.text().includes('404 (Not Found)')) errors.push(message.text());
  });
  try {
    await page.goto(adminUrl, { waitUntil: 'networkidle' });
    if (await page.getByRole('button', { name: 'Кирүү', exact: true }).count()) {
      await page.getByRole('button', { name: 'Кирүү', exact: true }).click();
    }
    await page.getByText('Система иштеп жатат', { exact: true }).waitFor();
    await page.getByText('Киреше', { exact: true }).waitFor();
    console.log('PASS admin login and dashboard');

    await page.getByRole('button', { name: /Китептер/ }).click();
    await page.getByRole('button', { name: /Китеп кошуу/ }).click();
    await page.getByRole('heading', { name: 'Жаңы китеп', exact: true }).waitFor();
    assert.equal(await page.getByLabel('Мукаба *').getAttribute('required'), '');
    assert.equal(await page.getByLabel('EPUB *').getAttribute('required'), '');
    await page.getByRole('button', { name: 'Жокко чыгаруу' }).click();
    console.log('PASS atomic create-book form requires cover and EPUB');

    await page.getByRole('button', { name: /Авторлор жана жанрлар/ }).click();
    const suffix = Date.now();
    const authorName = `QA UI ${suffix}`;
    const renamedAuthor = `QA UI өзгөргөн ${suffix}`;
    await page.getByPlaceholder('Автордун аты').fill(authorName);
    await page.locator('form').filter({ has: page.getByPlaceholder('Автордун аты') }).getByRole('button', { name: 'Кошуу' }).click();
    await page.getByText(authorName, { exact: true }).waitFor();
    const qaRow = page.locator('.simple-list article').filter({ hasText: authorName });
    await page.evaluate((name) => {
      window.prompt = () => name;
    }, renamedAuthor);
    await qaRow.getByRole('button', { name: 'Өзгөртүү' }).click({ force: true });
    await page.getByText(renamedAuthor, { exact: true }).waitFor();
    const renamedRow = page.locator('.simple-list article').filter({ hasText: renamedAuthor });
    page.once('dialog', (dialog) => dialog.accept());
    await renamedRow.getByRole('button', { name: 'Өчүрүү' }).click();
    await renamedRow.waitFor({ state: 'hidden' });
    console.log('PASS author create, edit and delete');

    await page.getByRole('button', { name: /Окурмандар/ }).click();
    const readerRow = page.locator('tbody tr').first();
    const toggle = readerRow.getByRole('button', { name: /Бөгөттөө|Ачуу/ });
    const before = await toggle.textContent();
    await toggle.click();
    await readerRow.getByRole('button', { name: before === 'Бөгөттөө' ? 'Ачуу' : 'Бөгөттөө' }).waitFor();
    await readerRow.getByRole('button', { name: before === 'Бөгөттөө' ? 'Ачуу' : 'Бөгөттөө' }).click();
    console.log('PASS reader block and unblock');

    await page.getByRole('button', { name: /Отчёттор/ }).click();
    await page.getByText('Китеп сатуу отчёту', { exact: true }).waitFor();
    await page.getByRole('button', { name: 'Көрсөтүү' }).click();
    await page.getByText('Китептер жана авторлор боюнча', { exact: true }).waitFor();
    console.log('PASS sales report by period');

    await page.getByRole('button', { name: /Аракеттер журналы/ }).click();
    await page.getByText('Администраторлордун аракеттери', { exact: true }).waitFor();
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
