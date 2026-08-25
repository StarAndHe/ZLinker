#!/usr/bin/env node
/**
 * Scripted, polished screen-recording of the ZLinker web app.
 *
 * Drives the REAL app (lib/main.dart, built to build/web) with a fake
 * animated cursor, click ripples and a zoom-in-on-tap effect, then records
 * the browser viewport to a video. This reproduces the "click + zoom" demo
 * feel with a committed, reusable script (no Cursor-internal recorder).
 *
 * Prereqs (handled by tool/record_demo.sh):
 *   - `flutter build web` has produced build/web
 *   - a static server serves it at DEMO_URL
 *   - `npm --prefix tool install` (puppeteer) and `ffmpeg` on PATH
 *
 * Env:
 *   DEMO_URL   default http://127.0.0.1:8890/index.html
 *   DEMO_OUT   default build/demo/zlinker-add-device.mp4
 *   DEMO_KEEP_WEBM=1  keep the intermediate .webm
 *
 * Usage: node tool/demo_recorder.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const URL = process.env.DEMO_URL || 'http://127.0.0.1:8890/index.html';
const OUT = path.resolve(ROOT, process.env.DEMO_OUT || 'build/demo/zlinker-add-device.mp4');

// Phone viewport that matches the app's mobile layout and the store screenshots.
const VW = 430, VH = 932, DSR = 2;
const DEMO_URL_VALUE =
  'https://zcode.z.ai/remote/v4?sid=demo123&hash=abc&t=1&mid=m1&name=DemoDevice';

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

// Declarative flow. Coordinates are in CSS px for the VWxVH viewport.
// kind: 'tap' | 'type' | 'pause'
const STEPS = [
  { kind: 'pause', ms: 1100, caption: '空的设备列表' },
  { kind: 'tap', x: 350, y: 892, zoom: 1.35, caption: '点击「添加设备」' },
  { kind: 'tap', x: 150, y: 890, zoom: 1.4, caption: '选择「粘贴链接添加」' },
  { kind: 'tap', x: 215, y: 462, zoom: 1.5, hold: 250, caption: '粘贴远程控制链接' },
  { kind: 'type', text: DEMO_URL_VALUE, zoomAt: [215, 462], zoom: 1.5, caption: '粘贴远程控制链接' },
  { kind: 'tap', x: 336, y: 540, zoom: 1.4, hold: 1600, caption: '确认添加' },
  { kind: 'pause', ms: 1200, caption: '设备已出现在列表' },
  { kind: 'tap', x: 370, y: 28, zoom: 1.3, hold: 1400, caption: '打开设置页' },
  { kind: 'pause', ms: 1600, caption: '设置:主题 · 语言 · 通知' },
];

const SHOW_CAPTIONS = process.env.DEMO_NO_CAPTIONS ? false : true;

function overlayInit() {
  const v = document.querySelector('flutter-view') || document.body;
  v.style.transition = 'transform 380ms cubic-bezier(.22,.61,.36,1)';
  v.style.transformOrigin = '0 0';

  const layer = document.createElement('div');
  Object.assign(layer.style, {
    position: 'fixed', inset: '0', zIndex: '2147483647', pointerEvents: 'none',
    overflow: 'hidden',
  });
  document.documentElement.appendChild(layer);

  const cur = document.createElement('div');
  cur.innerHTML =
    '<svg width="30" height="30" viewBox="0 0 30 30" fill="none">' +
    '<path d="M5 3 L5 24 L11 18 L15 27 L19 25 L15 16 L23 16 Z" ' +
    'fill="white" stroke="rgba(6,18,28,.9)" stroke-width="1.4" stroke-linejoin="round"/></svg>';
  Object.assign(cur.style, {
    position: 'absolute', left: '215px', top: '470px', width: '30px', height: '30px',
    transform: 'translate(-3px,-2px)', transition: 'left 620ms cubic-bezier(.4,0,.2,1),top 620ms cubic-bezier(.4,0,.2,1)',
    filter: 'drop-shadow(0 3px 5px rgba(0,0,0,.55))',
  });
  layer.appendChild(cur);

  const cap = document.createElement('div');
  Object.assign(cap.style, {
    position: 'absolute', left: '50%', bottom: '54px', transform: 'translateX(-50%) translateY(12px)',
    maxWidth: '82%', padding: '11px 20px', borderRadius: '999px',
    background: 'rgba(20,23,28,.86)', border: '1px solid rgba(60,68,84,.9)',
    color: '#F5F6F8', font: '600 17px/1.2 -apple-system,Inter,"WenQuanYi Micro Hei",sans-serif',
    letterSpacing: '.2px', whiteSpace: 'nowrap', opacity: '0',
    transition: 'opacity 260ms ease, transform 260ms ease', backdropFilter: 'blur(6px)',
    boxShadow: '0 8px 24px rgba(0,0,0,.4)',
  });
  layer.appendChild(cap);

  window.__demo = {
    moveTo(x, y) { cur.style.left = x + 'px'; cur.style.top = y + 'px'; },
    press() { cur.style.transform = 'translate(-3px,-2px) scale(.82)'; },
    release() { cur.style.transform = 'translate(-3px,-2px) scale(1)'; },
    ripple(x, y) {
      const r = document.createElement('div');
      Object.assign(r.style, {
        position: 'absolute', left: x + 'px', top: y + 'px', width: '14px', height: '14px',
        margin: '-7px 0 0 -7px', borderRadius: '50%', border: '2px solid rgba(56,189,248,.95)',
        background: 'rgba(56,189,248,.28)', transform: 'scale(1)', opacity: '1',
        transition: 'transform 520ms ease-out, opacity 520ms ease-out',
      });
      layer.appendChild(r);
      requestAnimationFrame(() => { r.style.transform = 'scale(6)'; r.style.opacity = '0'; });
      setTimeout(() => r.remove(), 560);
    },
    zoom(x, y, s) { v.style.transformOrigin = x + 'px ' + y + 'px'; v.style.transform = 'scale(' + s + ')'; },
    reset() { v.style.transform = 'none'; },
    caption(text) {
      if (!text) { cap.style.opacity = '0'; cap.style.transform = 'translateX(-50%) translateY(12px)'; return; }
      cap.textContent = text;
      cap.style.opacity = '1'; cap.style.transform = 'translateX(-50%) translateY(0)';
    },
  };
}

async function run() {
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  const webm = OUT.replace(/\.mp4$/i, '') + '.webm';

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage',
      '--force-device-scale-factor=' + DSR, '--hide-scrollbars'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: VW, height: VH, deviceScaleFactor: DSR });
  console.log('Loading', URL);
  await page.goto(URL, { waitUntil: 'networkidle0', timeout: 120000 });
  await wait(6000); // let Flutter paint the empty state
  await page.evaluate(overlayInit);
  await wait(300);

  console.log('Recording ->', webm);
  const recorder = await page.screencast({ path: webm });
  await wait(700);

  const setCap = (t) => page.evaluate((x) => window.__demo.caption(x), SHOW_CAPTIONS ? (t || '') : '');

  for (const s of STEPS) {
    await setCap(s.caption);
    if (s.kind === 'pause') { await wait(s.ms || 1000); continue; }

    if (s.kind === 'tap') {
      await page.evaluate((x, y) => window.__demo.moveTo(x, y), s.x, s.y);
      await wait(660);
      if (s.zoom) { await page.evaluate((x, y, z) => window.__demo.zoom(x, y, z), s.x, s.y, s.zoom); await wait(380); }
      await page.evaluate(() => window.__demo.press());
      await page.evaluate((x, y) => window.__demo.ripple(x, y), s.x, s.y);
      await page.mouse.click(s.x, s.y);
      await wait(140);
      await page.evaluate(() => window.__demo.release());
      await wait(s.hold ?? 550);
      if (s.zoom) { await page.evaluate(() => window.__demo.reset()); await wait(400); }
    }

    if (s.kind === 'type') {
      const [zx, zy] = s.zoomAt || [VW / 2, VH / 2];
      if (s.zoom) { await page.evaluate((x, y, z) => window.__demo.zoom(x, y, z), zx, zy, s.zoom); await wait(360); }
      await page.keyboard.type(s.text, { delay: 26 });
      await wait(700);
      if (s.zoom) { await page.evaluate(() => window.__demo.reset()); await wait(400); }
    }
  }

  await setCap('');
  await wait(700);
  await recorder.stop();
  await browser.close();
  console.log('Saved', webm);

  // Transcode to a widely-compatible mp4.
  const ff = spawnSync('ffmpeg', ['-y', '-i', webm,
    '-movflags', '+faststart', '-pix_fmt', 'yuv420p',
    '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2', '-r', '30', '-c:v', 'libx264', '-crf', '20', OUT],
    { stdio: 'inherit' });
  if (ff.status !== 0) { console.error('ffmpeg failed; webm kept at', webm); process.exit(1); }
  if (!process.env.DEMO_KEEP_WEBM) fs.rmSync(webm, { force: true });
  console.log('Done ->', OUT);
}

run().catch((e) => { console.error(e); process.exit(1); });
