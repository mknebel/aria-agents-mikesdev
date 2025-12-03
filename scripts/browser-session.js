#!/usr/bin/env node
/**
 * Browser Session - Persistent Playwright session for agent control
 *
 * Usage:
 *   node browser-session.js                    # Start session (headless)
 *   node browser-session.js --visible          # Start with visible browser
 *
 * Then send commands via stdin (JSON):
 *   {"action": "navigate", "url": "https://example.com"}
 *   {"action": "click", "selector": "#button"}
 *   {"action": "fill", "selector": "#input", "value": "text"}
 *   {"action": "screenshot", "path": "/tmp/shot.png"}
 *   {"action": "content"}
 *   {"action": "eval", "js": "document.title"}
 *   {"action": "close"}
 */

const { chromium } = require('playwright');
const readline = require('readline');
const path = require('path');
const fs = require('fs');

const SCREENSHOT_DIR = process.env.HOME + '/.claude/browser-screenshots';
const VIDEO_DIR = process.env.HOME + '/.claude/browser-videos';

// Ensure directories exist
[SCREENSHOT_DIR, VIDEO_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

const visible = process.argv.includes('--visible');
const recordVideo = process.argv.includes('--video');

let browser, context, page;

async function init() {
    console.error(`🚀 Starting browser session (${visible ? 'visible' : 'headless'})...`);

    browser = await chromium.launch({
        headless: !visible,
        slowMo: visible ? 100 : 0  // Slow down for visibility
    });

    const contextOptions = {};
    if (recordVideo) {
        contextOptions.recordVideo = {
            dir: VIDEO_DIR,
            size: { width: 1280, height: 720 }
        };
    }

    context = await browser.newContext(contextOptions);
    page = await context.newPage();

    // Log console messages
    page.on('console', msg => {
        console.error(`[browser] ${msg.type()}: ${msg.text()}`);
    });

    console.error('✓ Browser ready. Send JSON commands via stdin.');
    console.error('Commands: navigate, click, fill, screenshot, content, eval, wait, close');
}

async function handleCommand(cmd) {
    const startTime = Date.now();
    let result = { success: true };

    try {
        switch (cmd.action) {
            case 'navigate':
            case 'goto':
                await page.goto(cmd.url, { waitUntil: 'domcontentloaded' });
                result.url = page.url();
                result.title = await page.title();
                break;

            case 'click':
                await page.click(cmd.selector, { timeout: cmd.timeout || 5000 });
                result.clicked = cmd.selector;
                break;

            case 'fill':
            case 'type':
                await page.fill(cmd.selector, cmd.value);
                result.filled = cmd.selector;
                break;

            case 'screenshot':
            case 'ss':
                const ssPath = cmd.path || path.join(SCREENSHOT_DIR, `screenshot-${Date.now()}.png`);
                await page.screenshot({ path: ssPath, fullPage: cmd.fullPage !== false });
                result.path = ssPath;
                break;

            case 'content':
            case 'html':
                const content = await page.content();
                // Return truncated content to avoid huge responses
                result.content = content.substring(0, cmd.maxLength || 10000);
                result.length = content.length;
                break;

            case 'text':
                const text = await page.innerText(cmd.selector || 'body');
                result.text = text.substring(0, cmd.maxLength || 5000);
                break;

            case 'eval':
            case 'evaluate':
                result.result = await page.evaluate(cmd.js);
                break;

            case 'wait':
                if (cmd.selector) {
                    await page.waitForSelector(cmd.selector, { timeout: cmd.timeout || 10000 });
                    result.found = cmd.selector;
                } else if (cmd.ms) {
                    await page.waitForTimeout(cmd.ms);
                    result.waited = cmd.ms;
                } else if (cmd.url) {
                    await page.waitForURL(cmd.url, { timeout: cmd.timeout || 10000 });
                    result.url = page.url();
                }
                break;

            case 'select':
                await page.selectOption(cmd.selector, cmd.value);
                result.selected = cmd.value;
                break;

            case 'check':
                await page.check(cmd.selector);
                result.checked = cmd.selector;
                break;

            case 'uncheck':
                await page.uncheck(cmd.selector);
                result.unchecked = cmd.selector;
                break;

            case 'hover':
                await page.hover(cmd.selector);
                result.hovered = cmd.selector;
                break;

            case 'press':
                await page.press(cmd.selector || 'body', cmd.key);
                result.pressed = cmd.key;
                break;

            case 'url':
                result.url = page.url();
                break;

            case 'title':
                result.title = await page.title();
                break;

            case 'cookies':
                result.cookies = await context.cookies();
                break;

            case 'close':
            case 'quit':
            case 'exit':
                await cleanup();
                result.closed = true;
                console.log(JSON.stringify(result));
                process.exit(0);
                break;

            default:
                result.success = false;
                result.error = `Unknown action: ${cmd.action}`;
        }
    } catch (err) {
        result.success = false;
        result.error = err.message;
    }

    result.duration = Date.now() - startTime;
    return result;
}

async function cleanup() {
    console.error('🛑 Closing browser...');
    if (context) await context.close();
    if (browser) await browser.close();
}

async function main() {
    await init();

    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: false
    });

    rl.on('line', async (line) => {
        line = line.trim();
        if (!line) return;

        try {
            const cmd = JSON.parse(line);
            console.error(`→ ${cmd.action} ${cmd.url || cmd.selector || cmd.js || ''}`);
            const result = await handleCommand(cmd);
            console.log(JSON.stringify(result));
        } catch (err) {
            console.log(JSON.stringify({ success: false, error: `Parse error: ${err.message}` }));
        }
    });

    rl.on('close', async () => {
        await cleanup();
    });

    // Handle signals
    process.on('SIGINT', async () => {
        await cleanup();
        process.exit(0);
    });
    process.on('SIGTERM', async () => {
        await cleanup();
        process.exit(0);
    });
}

main().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
