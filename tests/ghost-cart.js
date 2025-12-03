// Ghost Cart Test - Full flow
const { chromium } = require('/home/mike/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const path = require('path');

const SCREENSHOT_DIR = '/home/mike/.claude/browser-screenshots';
const BASE_URL = 'http://localhost/LaunchYourKid/LaunchYourKid-Cake4/register';

(async () => {
  console.log('🚀 Ghost Cart Test for mike@knebel.net\n');

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    // Step 1: Login
    console.log('📌 Step 1: Login...');
    await page.goto(`${BASE_URL}/users/login`);
    await page.fill('input[name="email"]', 'mike@knebel.net');
    await page.fill('input[name="password"]', 'Thelmr99');
    await page.click('button[type="submit"], input[type="submit"]');
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'ghost-01-dashboard.png'), fullPage: true });
    console.log('✅ Logged in as Michael');

    // Step 2: Go to cart
    console.log('\n📌 Step 2: Navigate to cart...');
    // Look for "View Cart" text link
    const viewCartLink = await page.$('text=View Cart');
    if (viewCartLink) {
      await viewCartLink.click();
    } else {
      // Fallback: direct navigation
      await page.goto(`${BASE_URL}/cart`);
    }
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'ghost-02-cart-before.png'), fullPage: true });
    console.log('✅ Cart page loaded. URL:', page.url());

    // Step 3: Check cart contents
    console.log('\n📌 Step 3: Current cart contents...');
    const cartText = await page.textContent('body');
    console.log('Cart page preview:\n', cartText.slice(0, 1500));

    // Step 4: Clear cart (remove all items)
    console.log('\n📌 Step 4: Clearing cart...');
    let removeButtons = await page.$$('button:has-text("Remove"), a:has-text("Remove"), .remove-item, [data-action="remove"]');
    let removedCount = 0;
    while (removeButtons.length > 0) {
      await removeButtons[0].click();
      await page.waitForLoadState('networkidle');
      removedCount++;
      removeButtons = await page.$$('button:has-text("Remove"), a:has-text("Remove"), .remove-item, [data-action="remove"]');
    }
    console.log(`✅ Removed ${removedCount} items`);
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'ghost-03-cart-empty.png'), fullPage: true });

    // Step 5: Go to shop and add one item
    console.log('\n📌 Step 5: Adding one program...');
    await page.goto(`${BASE_URL}/programs`);
    await page.waitForLoadState('networkidle');

    // Find an "Add" or "Register" button
    const addButton = await page.$('button:has-text("Add"), a:has-text("Add"), a:has-text("Register"), button:has-text("Register")');
    if (addButton) {
      await addButton.click();
      await page.waitForLoadState('networkidle');
      console.log('✅ Clicked add/register button');
    } else {
      console.log('⚠️ No add button found on programs page');
      // List available buttons/links
      const buttons = await page.$$eval('a, button', els => els.map(e => e.textContent?.trim()).filter(t => t).slice(0, 20));
      console.log('Available actions:', buttons);
    }
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'ghost-04-add-item.png'), fullPage: true });

    // Step 6: View updated cart
    console.log('\n📌 Step 6: View cart after adding...');
    await page.goto(`${BASE_URL}/cart`);
    await page.waitForLoadState('networkidle');
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'ghost-05-cart-with-item.png'), fullPage: true });

    const newCartText = await page.textContent('body');
    console.log('Cart after adding:\n', newCartText.slice(0, 1500));

    console.log('\n✅ Test complete! Screenshots saved to:', SCREENSHOT_DIR);
    console.log('\nNext steps would be: checkout, payment, verify confirmation');

  } catch (err) {
    console.error('❌ Error:', err.message);
    await page.screenshot({ path: path.join(SCREENSHOT_DIR, 'ghost-error.png'), fullPage: true });
  } finally {
    await browser.close();
  }
})();
