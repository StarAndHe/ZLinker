#!/usr/bin/env node
/**
 * Capture Flutter web screenshot demo frames for README.
 * Requires: npm --prefix tool install puppeteer
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, '..', 'docs', 'screenshots');
const PORT = process.env.SHOT_PORT || '8765';
const BASE = `http://127.0.0.1:${PORT}/index.html`;

const shots = [
  { shot: 'list', width: 390, height: 844, file: '01-list-mobile.png' },
  { shot: 'chat', width: 390, height: 844, file: '02-chat-mobile.png' },
  { shot: 'dual', width: 1280, height: 900, file: '03-dual-pane.png' },
];

fs.mkdirSync(OUT, { recursive: true });
const browser = await puppeteer.launch({
  headless: 'new',
  args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
});

for (const { shot, width, height, file } of shots) {
  const page = await browser.newPage();
  await page.setViewport({ width, height, deviceScaleFactor: 1 });
  await page.goto(`${BASE}?shot=${shot}`, { waitUntil: 'networkidle0', timeout: 120000 });
  await page.waitForFunction(
    () => document.title.startsWith('zremote-ready-'),
    { timeout: 120000 },
  );
  await new Promise((r) => setTimeout(r, shot === 'dual' ? 800 : 500));
  await page.screenshot({ path: path.join(OUT, file), type: 'png' });
  await page.close();
  console.log(`Wrote ${file}`);
}

await browser.close();
