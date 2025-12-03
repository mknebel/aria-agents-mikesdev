import { test, expect } from '@playwright/test';

test('Ghost Cart Test - mike@knebel.net', async ({ page }) => {
  // Step 1: Navigate to login
  console.log('Step 1: Navigate to login page...');
  await page.goto('http://localhost/LaunchYourKid/LaunchYourKid-Cake4/register/users/login');
  await page.screenshot({ path: '/home/mike/.claude/browser-screenshots/ghost-01-login.png', fullPage: true });

  // Step 2: Login
  console.log('Step 2: Logging in as mike@knebel.net...');
  await page.fill('input[name="email"], input[type="email"], #email', 'mike@knebel.net');
  await page.fill('input[name="password"], input[type="password"], #password', 'Thelmr99');
  await page.click('button[type="submit"], input[type="submit"], .login-btn, .submit');
  await page.waitForLoadState('networkidle');
  await page.screenshot({ path: '/home/mike/.claude/browser-screenshots/ghost-02-after-login.png', fullPage: true });
  console.log('Logged in. Current URL:', page.url());

  // Step 3: Find and click cart
  console.log('Step 3: Looking for cart...');
  const cartSelectors = [
    'a[href*="cart"]',
    'a[href*="checkout"]',
    '.cart-link',
    '.cart-icon',
    'a:has-text("Cart")',
    'a:has-text("Checkout")',
    '[class*="cart"]'
  ];

  let cartFound = false;
  for (const selector of cartSelectors) {
    const el = await page.$(selector);
    if (el) {
      console.log(`Found cart with selector: ${selector}`);
      await el.click();
      await page.waitForLoadState('networkidle');
      cartFound = true;
      break;
    }
  }

  if (!cartFound) {
    console.log('No cart link found. Listing available links...');
    const links = await page.$$eval('a', els =>
      els.map(e => ({ text: e.textContent?.trim().slice(0,50), href: e.href }))
        .filter(l => l.text && l.href)
        .slice(0, 30)
    );
    console.log('Available links:', JSON.stringify(links, null, 2));
  }

  await page.screenshot({ path: '/home/mike/.claude/browser-screenshots/ghost-03-cart.png', fullPage: true });
  console.log('Current URL:', page.url());
  console.log('Page title:', await page.title());

  // Get current cart contents
  const bodyText = await page.textContent('body');
  console.log('Page body preview (first 1000 chars):', bodyText?.slice(0, 1000));
});
