const assert = require('node:assert/strict');
const { chromium } = require('playwright');

const baseUrl = process.env.KITAPP_URL || 'http://127.0.0.1:8083';
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

async function openReader(page) {
  await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 15000 });
  await enableFlutterAccessibility(page);

  await page
    .getByRole('button', { name: /Бриллиант жылан/ })
    .first()
    .click();

  const readButton = page.getByRole('button', {
    name: /Окууну (баштоо|улантуу)/,
  });

  if (!(await readButton.count())) {
    await page.getByRole('button', { name: /сатып алуу/ }).click();
    await page.getByRole('button', { name: 'Ооба', exact: true }).click();
  }

  await page
    .getByRole('button', { name: /Окууну (баштоо|улантуу)/ })
    .click();
  await page.waitForSelector('[aria-label="Publication"] iframe', {
    timeout: 15000,
  });
  await page.waitForTimeout(800);
}

async function openAndCloseReaderTool(page, label, marker) {
  const tool = page.getByText(label, { exact: true });
  assert.equal(await tool.count(), 1, `${label} must be available in the menu`);
  await tool.click();

  const panelMarker = page.getByText(marker, { exact: true });
  await panelMarker.waitFor({ state: 'visible' });

  const back = page.getByRole('button', { name: 'Артка', exact: true });
  assert.equal(await back.count(), 1, `${label} must have a back button`);
  await back.click();
  await panelMarker.waitFor({ state: 'hidden' });
}

(async () => {
  const browser = await chromium.launch({
    headless: true,
    executablePath: bravePath,
  });
  const page = await browser.newPage({ viewport: { width: 480, height: 900 } });
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
          .getByRole('button', { name: /Бриллиант жылан/ })
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
      await openAndCloseReaderTool(page, 'Жөндөө', 'Горизонталдуу');
      await openAndCloseReaderTool(page, 'Мазмуну', 'Пролог');
      await openAndCloseReaderTool(page, 'Издөө', 'Акыркы издөөлөр');
      await openAndCloseReaderTool(page, 'Кыстармалар', 'Кыстармалар жок');
      console.log('PASS all reader tools open and close');
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
