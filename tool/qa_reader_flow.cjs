const assert = require('node:assert/strict');
const { chromium } = require('playwright');

const baseUrl = process.env.KITAPP_URL || 'http://127.0.0.1:8083';
const apiUrl = process.env.KITAPP_API_URL || 'http://127.0.0.1:3000/api';
const bravePath =
  process.env.BRAVE_PATH ||
  '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';

async function enableFlutterAccessibility(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) {
    await placeholder.evaluate((element) => element.click());
    await page.waitForTimeout(100);
  }
}

async function storageContains(page, value) {
  return page.evaluate(
    (expected) => Object.values(localStorage).some((item) => item.includes(expected)),
    value,
  );
}

async function storageHasKey(page, value) {
  return page.evaluate(
    (expected) => Object.keys(localStorage).some((key) => key.includes(expected)),
    value,
  );
}

async function savedLocator(page, bookId) {
  return page.evaluate(
    (id) =>
      Object.entries(localStorage).find(([key]) =>
        key.includes(`locator_${id}`),
      )?.[1] ?? null,
    bookId,
  );
}

async function savedStablePage(page, bookId) {
  return page.evaluate(
    (id) =>
      Object.entries(localStorage).find(([key]) =>
        key.includes(`reader_page_${id}`),
      )?.[1] ?? null,
    bookId,
  );
}

async function openReaderMenu(page) {
  if (!(await page.getByText('Жөндөө', { exact: true }).count())) {
    await page.mouse.click(240, 450);
    await page.waitForTimeout(250);
    await enableFlutterAccessibility(page);
  }
  await page.getByText('Жөндөө', { exact: true }).waitFor({ state: 'visible' });
}

async function readerFrameDiagnostics(page) {
  return Promise.all(
    page.frames().map(async (frame) => {
      try {
        return await frame.evaluate(() => {
          const target = document.querySelector('p') || document.body;
          const style = target ? getComputedStyle(target) : null;
          const root = getComputedStyle(document.documentElement);
          return {
            url: location.href,
            fontSize: style?.fontSize ?? null,
            rootFontSize: root.fontSize,
            bodyFontSize: getComputedStyle(document.body).fontSize,
            lineHeight: style?.lineHeight ?? null,
            color: style?.color ?? null,
            background: getComputedStyle(document.body).backgroundColor,
            userFontSize: root.getPropertyValue('--USER__fontSize'),
            userBackground: root.getPropertyValue('--USER__backgroundColor'),
            kitappFontSize: document.documentElement.dataset.kitappFontSize ?? null,
            kitappTheme: document.documentElement.dataset.kitappTheme ?? null,
          };
        });
      } catch (error) {
        return { url: frame.url(), error: error.message };
      }
    }),
  );
}

async function readerSearchDiagnostics(page) {
  for (const frame of page.frames()) {
    if (!frame.url().startsWith('blob:')) continue;
    return frame.evaluate(() => ({
      matches: document.querySelectorAll('mark[data-kitapp-search]').length,
      active: document.querySelectorAll('mark[data-kitapp-search-active]').length,
    }));
  }
  return { matches: 0, active: 0 };
}

async function openReader(page) {
  await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 15000 });
  await enableFlutterAccessibility(page);

  const getCode = page.getByRole('button', { name: 'Код алуу', exact: true });
  if (await getCode.count()) {
    const phone = `0555${String(Date.now()).slice(-6)}`;
    await page.getByRole('textbox', { name: /Телефон номери/ }).fill(phone);
    await getCode.click();
    await page.getByRole('textbox', { name: /6 орундуу код/ }).fill('111111');
    await page.getByRole('button', { name: 'Кирүү', exact: true }).click();
    await page.getByText('Жаңы болуп чыкты', { exact: true }).waitFor();
  }

  const alice = page
    .getByRole('button', { name: /Алиса кереметтер өлкөсүндө/ })
    .first();
  try {
    await alice.waitFor({ state: 'visible', timeout: 15000 });
  } catch (error) {
    await page.screenshot({ path: '/tmp/kitapp-catalog-timeout.png', fullPage: true });
    throw error;
  }
  await alice.click();

  await page
    .getByRole('button', { name: /Окууну (баштоо|улантуу)/ })
    .click();
  await page.waitForTimeout(3000);
  if (!(await page.locator('[aria-label="Publication"] iframe').count())) {
    await page.screenshot({ path: '/tmp/kitapp-reader-open.png', fullPage: true });
    throw new Error(`Reader iframe missing; screen text: ${await page.locator('body').innerText()}`);
  }
  await page.waitForSelector('[aria-label="Publication"] iframe', {
    timeout: 15000,
  });
  await page.waitForTimeout(800);
}

(async () => {
  const catalog = await fetch(`${apiUrl}/catalog/books`).then((response) => response.json());
  const readerBookId = catalog.find(
    (book) => book.title === 'Алиса кереметтер өлкөсүндө',
  )?.id;
  assert.ok(readerBookId, 'Alice fixture must exist in the catalog');
  const browser = await chromium.launch({
    headless: true,
    executablePath: bravePath,
  });
  const page = await browser.newPage({ viewport: { width: 480, height: 900 } });
  const progressRequests = [];
  let progressAuthorization = '';
  page.on('request', (request) => {
    if (!request.url().includes('/api/reader/progress')) return;
    progressRequests.push(request.postDataJSON());
    progressAuthorization =
      request.headers().authorization || progressAuthorization;
  });
  page.on('console', (message) => {
    if (message.type() === 'error' || message.text().includes('ERROR')) {
      console.error(`BROWSER ${message.type()}: ${message.text()}`);
    }
  });
  page.on('pageerror', (error) => console.error(`BROWSER pageerror: ${error.message}`));
  page.setDefaultTimeout(4000);
  const failures = [];

  try {
    await openReader(page);

    try {
      const sizes = await page.evaluate(() => {
        const wrapper = document.querySelector('#wrapper');
        const host = wrapper?.parentElement;
        const container = document.querySelector('#container');
        const frame = container?.querySelector('iframe');
        return {
          wrapper: wrapper?.getBoundingClientRect().height ?? 0,
          host: host?.getBoundingClientRect().height ?? 0,
          container: container?.getBoundingClientRect().height ?? 0,
          frame: frame?.getBoundingClientRect().height ?? 0,
          viewport: window.innerHeight,
        };
      });
      assert.ok(sizes.host > 0, 'reader host must have a visible height');
      assert.ok(
        Math.abs(sizes.viewport - sizes.wrapper) < 4 &&
          Math.abs(sizes.wrapper - sizes.container) < 4 &&
          Math.abs(sizes.container - sizes.frame) < 4,
        `reader must fill the viewport (viewport=${sizes.viewport}, wrapper=${sizes.wrapper}, container=${sizes.container}, frame=${sizes.frame})`,
      );
      console.log('PASS reader fills the available height');
    } catch (error) {
      failures.push(`black-area: ${error.message}`);
    }

    try {
      await page.waitForTimeout(1500);
      const publicationView = page.locator('[aria-label="Publication"]');
      const before = await publicationView.screenshot();
      const locatorBeforeSwipe = await savedLocator(page, readerBookId);
      await page.mouse.move(390, 450);
      await page.mouse.down();
      await page.mouse.move(90, 450, { steps: 12 });
      await page.mouse.up();
      await page.waitForTimeout(900);
      const after = await publicationView.screenshot();
      assert.ok(
        !after.equals(before),
        'horizontal swipe must change the visible page',
      );
      assert.notEqual(
        await savedLocator(page, readerBookId),
        locatorBeforeSwipe,
        'horizontal swipe must update the saved locator',
      );
      console.log('PASS horizontal swipe changes the page');
    } catch (error) {
      failures.push(`swipe: ${error.message}`);
    }

    try {
      await page.mouse.click(240, 450);
      await page.waitForTimeout(250);
      await enableFlutterAccessibility(page);
      const exit = page.getByText('Чыгуу', { exact: true });
      await assert.doesNotReject(() => exit.waitFor({ state: 'visible' }));
      await exit.click();
      await assert.doesNotReject(() =>
        page.getByText('Кыскача маалымат', { exact: true }).waitFor(),
      );
      console.log('PASS reader exit returns to the book card');
    } catch (error) {
      failures.push(`exit: ${error.message}`);
    }

    try {
      if (!(await page.getByText('Кыскача маалымат', { exact: true }).count())) {
        await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 15000 });
        await enableFlutterAccessibility(page);
        await page
          .getByRole('button', { name: /Алиса кереметтер өлкөсүндө/ })
          .first()
          .click();
      }
      await page
        .getByRole('button', { name: /Окууну (баштоо|улантуу)/ })
        .click();
      await page.waitForSelector('[aria-label="Publication"] iframe', {
        timeout: 15000,
      });
      await page.waitForTimeout(600);
      await page.mouse.click(240, 450);
      await page.waitForTimeout(250);
      await enableFlutterAccessibility(page);
      const publicationView = page.locator('[aria-label="Publication"]');

      await page.getByText('Жөндөө', { exact: true }).click();
      await page.getByText('Горизонталдуу', { exact: true }).waitFor();
      const readerBeforeFont = await publicationView.screenshot();
      const fontDown = page.getByRole('button', {
        name: 'Текст өлчөмү азайтуу',
      });
      const fontUp = page.getByRole('button', {
        name: 'Текст өлчөмү көбөйтүү',
      });
      for (let index = 0; index < 5; index++) await fontDown.click();
      await page.getByText('80%', { exact: true }).waitFor();
      for (let index = 0; index < 11; index++) await fontUp.click();
      await page.getByText('180%', { exact: true }).waitFor();
      await page.waitForTimeout(500);
      const readerAfterFont = await publicationView.screenshot();
      const readerStylesAfterFont = await readerFrameDiagnostics(page);
      const contentStyleAfterFont = readerStylesAfterFont.find((item) =>
        item.url.startsWith('blob:'),
      );
      assert.ok(
        !readerAfterFont.equals(readerBeforeFont),
        'font controls must visibly reflow the EPUB content',
      );
      assert.equal(
        contentStyleAfterFont?.kitappFontSize,
        '180',
        'font controls must apply to the EPUB document, not only to the settings label',
      );

      const brightnessDown = page.getByRole('button', {
        name: 'Жарыктыгы азайтуу',
      });
      const brightnessUp = page.getByRole('button', {
        name: 'Жарыктыгы көбөйтүү',
      });
      for (let index = 0; index < 7; index++) await brightnessDown.click();
      await page.getByText('40%', { exact: true }).waitFor();
      for (let index = 0; index < 7; index++) await brightnessUp.click();
      await page.getByText('100%', { exact: true }).waitFor();

      await page.getByText('Күндүзгү', { exact: true }).click();
      await page.waitForTimeout(100);
      assert.ok(await storageContains(page, 'light'), 'light theme must persist');
      await page.getByText('Сепия', { exact: true }).click();
      await page.waitForTimeout(100);
      assert.ok(await storageContains(page, 'sepia'), 'sepia theme must persist');
      await page.getByText('Түнкү', { exact: true }).click();
      await page.waitForTimeout(100);
      assert.ok(await storageContains(page, 'dark'), 'dark theme must persist');
      const readerStylesAfterTheme = await readerFrameDiagnostics(page);
      assert.equal(
        readerStylesAfterTheme.find((item) => item.url.startsWith('blob:'))?.kitappTheme,
        'dark',
        'theme controls must apply to the EPUB document',
      );
      await page.getByRole('button', { name: 'Артка', exact: true }).click();
      await page.getByText('Жөндөө', { exact: true }).waitFor();
      console.log('PASS settings enforce bounds, persist all themes, and restore menu');

      const beforeSlider = await publicationView.screenshot();
      const slider = page.getByRole('slider').first();
      const sliderBox = await slider.boundingBox();
      assert.ok(sliderBox, 'page slider must be visible');
      await page.mouse.click(
        sliderBox.x + sliderBox.width * 0.7,
        sliderBox.y + sliderBox.height / 2,
      );
      await page.waitForTimeout(1000);
      const afterSlider = await publicationView.screenshot();
      assert.ok(!afterSlider.equals(beforeSlider), 'page slider must navigate to another stable page');
      assert.ok(
        await storageHasKey(page, `reader_page_${readerBookId}`),
        'page slider result must persist the stable page number',
      );
      console.log('PASS stable page slider navigates and persists its page');

      const beforeChapter = await publicationView.screenshot();
      await page.getByText('Мазмуну', { exact: true }).click();
      await page.waitForTimeout(200);
      await enableFlutterAccessibility(page);
      const chapter = page.getByText(/CHAPTER VI\. Pig and Pepper/);
      await chapter.waitFor({ state: 'visible' });
      await chapter.click();
      await page.waitForTimeout(900);
      const afterChapter = await publicationView.screenshot();
      assert.ok(!afterChapter.equals(beforeChapter), 'contents item must navigate to its chapter');
      console.log('PASS contents navigates to the selected chapter');

      await page.getByText('Кыстармалар', { exact: true }).click();
      await page.getByText('Кыстармалар жок', { exact: true }).waitFor();
      await page.getByRole('button', { name: 'Артка', exact: true }).click();
      await page.getByText('Кыстармалар', { exact: true }).waitFor();
      console.log('PASS empty bookmarks state and persistent menu');

      await page.getByText('Издөө', { exact: true }).click();
      const search = page.getByRole('textbox', { name: /Китептин текстинен издөө/ });
      await search.fill('qa-no-result-7f3c9d');
      await page.getByText('Натыйжа табылган жок', { exact: true }).waitFor({
        state: 'visible',
        timeout: 15000,
      });
      await search.fill('White Rabbit');
      const searchResult = page.getByText(/White Rabbit/i).last();
      await searchResult.waitFor({ state: 'visible', timeout: 15000 });
      await searchResult.click();
      await page.waitForTimeout(500);
      const highlight = await readerSearchDiagnostics(page);
      assert.ok(highlight.matches > 0, 'search must highlight matching text inside the EPUB');
      assert.equal(highlight.active, 1, 'search must mark the selected occurrence as active');
      await page.getByRole('button', { name: 'Мурунку жерге кайтуу' }).click();
      await page.waitForTimeout(500);
      assert.equal(
        (await readerSearchDiagnostics(page)).matches,
        0,
        'back navigation must clear search highlighting and restore the previous place',
      );
      await page.getByRole('button', { name: 'Кийинки жерге өтүү' }).click();
      await page.waitForTimeout(500);
      await page.getByRole('button', { name: 'Кыстарма кошуу' }).click();
      console.log('PASS search highlighting, back/forward history, and result navigation');

      await page.getByText('Кыстармалар', { exact: true }).click();
      await page.getByText('Кыстармалар жок', { exact: true }).waitFor({ state: 'hidden' });
      await page.getByRole('button', { name: 'Кыстарма аракеттери' }).first().click();
      const renameAction = page.getByRole('menuitem', { name: 'Атын өзгөртүү' });
      await renameAction.waitFor({ state: 'visible' });
      await renameAction.click();
      const renameField = page.getByRole('textbox').last();
      await renameField.fill('QA кыстарма');
      await page.getByRole('button', { name: 'Сактоо', exact: true }).click();
      await page.waitForTimeout(500);
      const savedBookmarkTitles = await page.evaluate(() =>
        Object.values(localStorage).some((value) => value.includes('QA кыстарма')),
      );
      assert.ok(savedBookmarkTitles, 'renamed bookmark must be persisted locally');
      await page.getByRole('button', { name: 'Артка', exact: true }).click();
      await page.getByText('Кыстармалар', { exact: true }).waitFor();
      console.log('PASS bookmark add and rename persists locally');

      await page.getByText('Издөө', { exact: true }).click();
      await page.getByRole('textbox', { name: /Китептин текстинен издөө/ }).waitFor();
      const recentChip = page.getByRole('button', { name: 'Акыркы издөө: White Rabbit', exact: true });
      await recentChip.waitFor({ state: 'visible' });
      await recentChip.click();
      await page.getByText(/White Rabbit/i).last().waitFor({ state: 'visible', timeout: 15000 });
      await page.getByRole('button', { name: 'Артка', exact: true }).click();
      console.log('PASS recent search chip reruns full-text search');

      const bookmarkedPage = await publicationView.screenshot();
      await page.getByText('Мазмуну', { exact: true }).click();
      await page.getByText(/^CHAPTER XII\./).click();
      await page.waitForTimeout(900);
      const awayFromBookmark = await publicationView.screenshot();
      assert.ok(
        !awayFromBookmark.equals(bookmarkedPage),
        'precondition: contents must move away from the bookmark',
      );
      await openReaderMenu(page);
      await page.getByText('Кыстармалар', { exact: true }).click();
      await page.waitForTimeout(200);
      await enableFlutterAccessibility(page);
      const savedBookmark = page.getByRole('button', {
        name: /Кыстарманы ачуу: QA кыстарма/,
      });
      await savedBookmark.click();
      await page.waitForTimeout(900);
      const afterBookmarkJump = await publicationView.screenshot();
      assert.ok(
        !afterBookmarkJump.equals(awayFromBookmark),
        'bookmark selection must navigate away from the later chapter',
      );
      await page.mouse.click(240, 450);
      await openReaderMenu(page);
      await page.getByText('Кыстармалар', { exact: true }).click();
      await page.getByRole('button', { name: 'Кыстарма аракеттери' }).first().click();
      await page.getByRole('menuitem', { name: 'Өчүрүү', exact: true }).click();
      await page.getByText('Кыстармалар жок', { exact: true }).waitFor();
      await page.getByRole('button', { name: 'Артка', exact: true }).click();
      await page.getByText('Кыстармалар', { exact: true }).waitFor();
      console.log('PASS bookmark jump and delete, including empty state');

      await page.getByText('Мазмуну', { exact: true }).click();
      await page.getByText(/^CHAPTER X\./).click();
      await page.waitForTimeout(1200);
      const restoreTarget = await savedLocator(page, readerBookId);
      const restoreStablePage = await savedStablePage(page, readerBookId);
      assert.ok(restoreTarget, 'current locator must be persisted locally');
      assert.ok(restoreStablePage, 'stable page number must be persisted locally');
      await openReaderMenu(page);
      await page.getByText('Чыгуу', { exact: true }).click();
      await page.getByText('Кыскача маалымат', { exact: true }).waitFor();
      await page.getByRole('button', { name: /Окууну (баштоо|улантуу)/ }).click();
      await page.waitForSelector('[aria-label="Publication"] iframe', {
        timeout: 15000,
      });
      await page.waitForTimeout(1200);
      const restored = await savedLocator(page, readerBookId);
      assert.equal(restored, restoreTarget, 'reader must restore the saved locator');
      assert.equal(
        await savedStablePage(page, readerBookId),
        restoreStablePage,
        'reader must preserve the same stable page number',
      );
      await openReaderMenu(page);
      const stablePageNumber = Number(JSON.parse(restoreStablePage));
      await page.getByText(`${stablePageNumber} / 90-бет`, { exact: true }).waitFor();
      console.log('PASS saved progress restores after closing and reopening reader');

      if (process.env.KITAPP_LONG_QA === '1') {
        const deadline = Date.now() + 140000;
        while (
          progressRequests.reduce(
            (total, request) => total + (request.activeSeconds || 0),
            0,
          ) < 120 &&
          Date.now() < deadline
        ) {
          await page.waitForTimeout(1000);
        }
        const activeSeconds = progressRequests.reduce(
          (total, request) => total + (request.activeSeconds || 0),
          0,
        );
        assert.ok(
          activeSeconds >= 120,
          `reader must sync >=120 active seconds, got ${activeSeconds}`,
        );
        assert.ok(progressAuthorization, 'progress request must be authenticated');
        const response = await fetch('http://127.0.0.1:3000/api/reader/recent', {
          headers: { Authorization: progressAuthorization },
        });
        const recent = await response.json();
        assert.equal(response.status, 200, 'recent request must succeed');
        assert.ok(
          recent.some((item) => item.activeSeconds >= 120),
          'book must appear in recent after >=120 active seconds',
        );
        console.log('PASS >=120 active seconds persist and book appears in recent');
      }

      console.log('PASS all reader tools and outcomes');
    } catch (error) {
      failures.push(`tools: ${error.message}`);
    }
  } finally {
    await browser.close();
  }

  if (failures.length) {
    console.error(`FAIL ${failures.length} reader QA scenario(s)`);
    for (const failure of failures) console.error(`- ${failure}`);
    process.exitCode = 1;
  } else {
    console.log('PASS all reader QA scenarios');
  }
})();
