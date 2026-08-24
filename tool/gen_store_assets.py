#!/usr/bin/env python3
"""Generate App Store / Google Play marketing assets for ZRemote.

Outputs (under docs/store/):
  appstore/icon/app-icon-1024.png            1024x1024, no alpha
  appstore/screenshots/iphone-6.9/*.png      1290x2796  (en + zh)
  appstore/screenshots/ipad-13/*.png         2752x2064  (en + zh)
  googleplay/icon/play-icon-512.png          512x512
  googleplay/feature-graphic/*.png           1024x500   (en + zh)
  googleplay/screenshots/phone/*.png         1080x2400  (en + zh)
  googleplay/screenshots/tablet/*.png        1920x1200  (en + zh)

Source art: assets/icon/icon.png and the real app captures in
docs/screenshots/. Brand tokens mirror lib/ui/theme.dart.

Run:  python3 tool/gen_store_assets.py
Deps: Pillow  (pip install Pillow)
"""
from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "store")
SHOTS = os.path.join(ROOT, "docs", "screenshots")
ICON_SRC = os.path.join(ROOT, "assets", "icon", "icon.png")

# ── Brand tokens (from lib/ui/theme.dart) ───────────────────────────────
BG_TOP = (13, 13, 13)          # near-black top of gradient
BG_BOTTOM = (22, 22, 22)       # official dark background #161616
CARD = (34, 34, 34)            # #222 card surface
CARD_BORDER = (58, 65, 80)     # ring slate #3A4150
SKY = (56, 189, 248)           # sky-400 #38BDF8
SKY_DEEP = (14, 165, 233)      # sky-500 #0EA5E9
WHITE = (245, 245, 245)
MUTED = (163, 163, 163)        # neutral-400
DIM = (115, 115, 115)          # neutral-500

FONT_DIR = "/usr/share/fonts/truetype/macos"
CJK_FONT = "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc"


def font(weight: str, size: int, lang: str = "en") -> ImageFont.FreeTypeFont:
    if lang == "zh":
        return ImageFont.truetype(CJK_FONT, size)
    files = {
        "bold": "Inter-Bold.ttf",
        "semibold": "Inter-SemiBold.ttf",
        "medium": "Inter-Medium.ttf",
        "regular": "Inter-Regular.ttf",
    }
    return ImageFont.truetype(os.path.join(FONT_DIR, files[weight]), size)


# ── low-level drawing helpers ───────────────────────────────────────────
def gradient_bg(w: int, h: int) -> Image.Image:
    """Vertical dark gradient with a soft sky glow in the upper area."""
    base = Image.new("RGB", (w, h), BG_BOTTOM)
    top = Image.new("RGB", (1, h))
    tp = top.load()
    for y in range(h):
        t = y / max(1, h - 1)
        tp[0, y] = tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
    base = top.resize((w, h))

    glow = Image.new("L", (w, h), 0)
    gd = ImageDraw.Draw(glow)
    cx, cy = int(w * 0.5), int(h * 0.12)
    r = int(w * 0.75)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.18))
    sky_layer = Image.new("RGB", (w, h), SKY_DEEP)
    base = Image.composite(sky_layer, base, glow)
    return base


def rounded_mask(size, radius) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def drop_shadow(canvas: Image.Image, box, radius, blur, alpha=150, offset=(0, 28)):
    w, h = canvas.size
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sh)
    x0, y0, x1, y1 = box
    sd.rounded_rectangle([x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]],
                         radius=radius, fill=(0, 0, 0, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh)


def paste_rounded(canvas, img, xy, radius, border=None, border_w=0):
    mask = rounded_mask(img.size, radius)
    canvas.paste(img, xy, mask)
    if border:
        d = ImageDraw.Draw(canvas)
        x, y = xy
        d.rounded_rectangle([x, y, x + img.size[0] - 1, y + img.size[1] - 1],
                            radius=radius, outline=border, width=border_w)


# ── text helpers ────────────────────────────────────────────────────────
def wrap(draw, text, fnt, max_w, lang):
    if lang == "zh":
        lines, cur = [], ""
        for ch in text:
            if ch == "\n":
                lines.append(cur); cur = ""; continue
            if draw.textlength(cur + ch, font=fnt) <= max_w:
                cur += ch
            else:
                lines.append(cur); cur = ch
        if cur:
            lines.append(cur)
        return lines
    lines, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            lines.append(cur); cur = word
    if cur:
        lines.append(cur)
    return lines


def draw_block(draw, text, fnt, fill, x, y, max_w, lang, leading=1.18,
               align="left", stroke=0, stroke_fill=None):
    lines = wrap(draw, text, fnt, max_w, lang)
    asc, desc = fnt.getmetrics()
    lh = int((asc + desc) * leading)
    for i, ln in enumerate(lines):
        lw = draw.textlength(ln, font=fnt)
        if align == "center":
            lx = x + (max_w - lw) / 2
        elif align == "right":
            lx = x + (max_w - lw)
        else:
            lx = x
        draw.text((lx, y + i * lh), ln, font=fnt, fill=fill,
                  stroke_width=stroke, stroke_fill=stroke_fill)
    return y + len(lines) * lh


def load_icon(size: int) -> Image.Image:
    ic = Image.open(ICON_SRC).convert("RGBA")
    bg = Image.new("RGBA", ic.size, (*BG_BOTTOM, 255))
    ic = Image.alpha_composite(bg, ic)
    return ic.resize((size, size), Image.LANCZOS)


# ── device frames ───────────────────────────────────────────────────────
def phone_frame(shot: Image.Image, target_w: int) -> Image.Image:
    """Wrap a portrait screenshot in a phone bezel; returns RGBA."""
    bezel = max(10, int(target_w * 0.035))
    inner_w = target_w - 2 * bezel
    inner_h = int(inner_w * shot.size[1] / shot.size[0])
    shot = shot.convert("RGB").resize((inner_w, inner_h), Image.LANCZOS)
    frame_w = target_w
    frame_h = inner_h + 2 * bezel
    r_out = int(target_w * 0.13)
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    body = Image.new("RGBA", (frame_w, frame_h), (8, 8, 8, 255))
    frame.paste(body, (0, 0), rounded_mask((frame_w, frame_h), r_out))
    paste_rounded(frame, shot, (bezel, bezel), max(4, r_out - bezel))
    ImageDraw.Draw(frame).rounded_rectangle(
        [0, 0, frame_w - 1, frame_h - 1], radius=r_out, outline=CARD_BORDER, width=max(2, bezel // 5))
    return frame


def browser_frame(shot: Image.Image, target_w: int) -> Image.Image:
    """Wrap a landscape screenshot in a browser/tablet window; returns RGBA."""
    pad = max(2, int(target_w * 0.006))
    bar = int(target_w * 0.045)
    inner_w = target_w - 2 * pad
    inner_h = int(inner_w * shot.size[1] / shot.size[0])
    shot = shot.convert("RGB").resize((inner_w, inner_h), Image.LANCZOS)
    frame_w = target_w
    frame_h = inner_h + bar + pad
    r = int(target_w * 0.025)
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    body = Image.new("RGBA", (frame_w, frame_h), (28, 30, 34, 255))
    frame.paste(body, (0, 0), rounded_mask((frame_w, frame_h), r))
    d = ImageDraw.Draw(frame)
    cy = bar // 2
    for i, col in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        dotx = int(bar * 0.6) + i * int(bar * 0.5)
        rr = max(4, int(bar * 0.13))
        d.ellipse([dotx - rr, cy - rr, dotx + rr, cy + rr], fill=col)
    # square-ish top corners for the screen area under the bar
    frame.paste(shot, (pad, bar), )
    d.rounded_rectangle([0, 0, frame_w - 1, frame_h - 1], radius=r, outline=CARD_BORDER, width=max(2, pad))
    return frame


def wordmark(canvas, cx, y, lang, scale=1.0):
    """Small centered brand lockup: ring icon + ZRemote."""
    isz = int(64 * scale)
    ic = load_icon(isz)
    fnt = font("bold", int(46 * scale))
    d = ImageDraw.Draw(canvas)
    tw = d.textlength("ZRemote", font=fnt)
    total = isz + int(18 * scale) + tw
    x = int(cx - total / 2)
    canvas.alpha_composite(ic.convert("RGBA"), (x, int(y)))
    d.text((x + isz + int(18 * scale), int(y + isz / 2 - int(46 * scale) * 0.62)),
           "ZRemote", font=fnt, fill=WHITE)


# ── slide builders ──────────────────────────────────────────────────────
CAPTIONS = {
    "tasks": {
        "en": ("Every task, live", "Running state, reply previews and stop \u00b7 pause \u00b7 resume \u2014 from your phone."),
        "zh": ("\u4efb\u52a1\uff0c\u5b9e\u65f6\u638c\u63e1", "\u8fd0\u884c\u72b6\u6001\u3001\u56de\u590d\u9884\u89c8\uff0c\u505c\u6b62 \u00b7 \u6682\u505c \u00b7 \u6062\u590d\uff0c\u5c3d\u5728\u624b\u673a\u3002"),
    },
    "conversation": {
        "en": ("Native conversations", "Streaming replies, tool diffs and model switching \u2014 no browser."),
        "zh": ("\u539f\u751f\u5bf9\u8bdd\u4f53\u9a8c", "\u6d41\u5f0f\u56de\u590d\u3001\u5de5\u5177 diff\u3001\u6a21\u578b\u5207\u6362\uff0c\u65e0\u9700\u7f51\u9875\u3002"),
    },
    "dualpane": {
        "en": ("Desktop-class on tablet", "A sidebar + chat dual-pane above 768dp."),
        "zh": ("\u5e73\u677f\u4e0a\u7684\u684c\u9762\u7ea7\u5e03\u5c40", "768dp \u4ee5\u4e0a\uff0c\u4fa7\u680f + \u5bf9\u8bdd\u53cc\u680f\u5e76\u6392\u3002"),
    },
}

HERO = {
    "en": ("Your ZCode agent,\nin your pocket",
           ["Live tasks", "Automations", "Off-peak", "Notifications"]),
    "zh": ("\u628a ZCode \u667a\u80fd\u4f53\n\u88c5\u8fdb\u53e3\u888b",
           ["\u5b9e\u65f6\u4efb\u52a1", "\u5b9a\u65f6\u81ea\u52a8\u5316", "\u95f2\u65f6\u4efb\u52a1", "\u672c\u5730\u901a\u77e5"]),
}

FEATURES = {
    "en": ("Built for real work", [
        ("Scheduled automations", "cron \u00b7 intervals \u00b7 one-shot"),
        ("Off-peak tasks", "free compute, live queue position"),
        ("Push notifications", "tap to open the conversation"),
        ("Privacy first", "device links stay on your phone"),
    ]),
    "zh": ("\u4e3a\u771f\u5b9e\u5de5\u4f5c\u800c\u751f", [
        ("\u5b9a\u65f6\u81ea\u52a8\u5316", "cron \u00b7 \u56fa\u5b9a\u95f4\u9694 \u00b7 \u4e00\u6b21\u6027"),
        ("\u95f2\u65f6\u4efb\u52a1", "\u514d\u8d39\u7b97\u529b\uff0c\u6392\u961f\u5b9e\u65f6\u53ef\u89c1"),
        ("\u63a8\u9001\u901a\u77e5", "\u70b9\u6309\u76f4\u8fbe\u5bf9\u8bdd"),
        ("\u9690\u79c1\u4f18\u5148", "\u8bbe\u5907\u94fe\u63a5\u53ea\u5b58\u672c\u673a"),
    ]),
}


def showcase_portrait(w, h, shot_path, key, lang):
    canvas = gradient_bg(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    title, sub = CAPTIONS[key][lang]
    margin = int(w * 0.085)
    y = int(h * 0.06)
    hf = font("bold", int(w * 0.078), lang)
    y = draw_block(d, title, hf, WHITE, margin, y, w - 2 * margin, lang,
                   align="center", leading=1.1,
                   stroke=2 if lang == "zh" else 0, stroke_fill=WHITE)
    y += int(h * 0.012)
    sf = font("medium", int(w * 0.038), lang)
    y = draw_block(d, sub, sf, MUTED, margin, y, w - 2 * margin, lang,
                   align="center", leading=1.25)

    shot = Image.open(shot_path)
    frame = phone_frame(shot, int(w * 0.74))
    fx = (w - frame.size[0]) // 2
    fy = int(h * 0.30)
    if fy + frame.size[1] > h * 0.93:
        frame = phone_frame(shot, int((h * 0.93 - fy) * shot.size[0] / shot.size[1] * 0.96))
        fx = (w - frame.size[0]) // 2
    drop_shadow(canvas, [fx, fy, fx + frame.size[0], fy + frame.size[1]],
                int(w * 0.096), int(w * 0.04))
    canvas.alpha_composite(frame, (fx, fy))
    wordmark(canvas, w / 2, h * 0.945, lang, scale=w / 1290 * 0.9)
    return canvas.convert("RGB")


def showcase_landscape(w, h, shot_path, key, lang):
    canvas = gradient_bg(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    title, sub = CAPTIONS[key][lang]
    margin = int(w * 0.06)
    y = int(h * 0.055)
    hf = font("bold", int(w * 0.036), lang)
    y = draw_block(d, title, hf, WHITE, margin, y, w - 2 * margin, lang,
                   align="center", leading=1.1,
                   stroke=2 if lang == "zh" else 0, stroke_fill=WHITE)
    y += int(h * 0.01)
    sf = font("medium", int(w * 0.019), lang)
    draw_block(d, sub, sf, MUTED, margin, y, w - 2 * margin, lang, align="center")

    # Fit the browser frame into the band between the caption and the wordmark.
    shot = Image.open(shot_path)
    avail_top = int(h * 0.24)
    avail_h = int(h * 0.66)
    frame = browser_frame(shot, int(w * 0.80))
    if frame.size[1] > avail_h:
        frame = browser_frame(shot, int(w * 0.80 * avail_h / frame.size[1]))
    fx = (w - frame.size[0]) // 2
    fy = avail_top + (avail_h - frame.size[1]) // 2
    drop_shadow(canvas, [fx, fy, fx + frame.size[0], fy + frame.size[1]],
                int(w * 0.02), int(w * 0.02))
    canvas.alpha_composite(frame, (fx, fy))
    wordmark(canvas, w / 2, h * 0.945, lang, scale=w / 2752 * 1.4)
    return canvas.convert("RGB")


def hero_slide(w, h, lang):
    canvas = gradient_bg(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    isz = int(w * 0.42)
    ic = load_icon(isz)
    ix = (w - isz) // 2
    iy = int(h * 0.18)
    drop_shadow(canvas, [ix, iy, ix + isz, iy + isz], int(isz * 0.23), int(w * 0.05), alpha=170)
    canvas.alpha_composite(ic.convert("RGBA"), (ix, iy))

    d.text((w / 2, iy + isz + int(h * 0.045)), "ZRemote",
           font=font("bold", int(w * 0.11)), fill=WHITE, anchor="mm")

    tag, chips = HERO[lang]
    tf = font("medium", int(w * 0.05), lang)
    ty = iy + isz + int(h * 0.085)
    draw_block(d, tag, tf, SKY, int(w * 0.08), ty, int(w * 0.84), lang,
               align="center", leading=1.22)

    # feature chips
    cf = font("semibold", int(w * 0.032), lang)
    cy = int(h * 0.80)
    gap = int(w * 0.03)
    ch_h = int(w * 0.085)
    # two rows of two chips
    rows = [chips[:2], chips[2:]]
    for r, row in enumerate(rows):
        widths = [d.textlength(c, font=cf) + int(w * 0.07) for c in row]
        total = sum(widths) + gap * (len(row) - 1)
        x = (w - total) / 2
        yy = cy + r * (ch_h + int(h * 0.016))
        for c, cw in zip(row, widths):
            d.rounded_rectangle([x, yy, x + cw, yy + ch_h], radius=ch_h // 2,
                                fill=CARD, outline=CARD_BORDER, width=2)
            dotr = int(ch_h * 0.11)
            dcx = x + int(w * 0.028)
            d.ellipse([dcx - dotr, yy + ch_h / 2 - dotr, dcx + dotr, yy + ch_h / 2 + dotr], fill=SKY)
            d.text((dcx + int(w * 0.02), yy + ch_h / 2), c, font=cf, fill=WHITE, anchor="lm")
            x += cw + gap
    return canvas.convert("RGB")


def features_slide(w, h, lang):
    canvas = gradient_bg(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    title, items = FEATURES[lang]
    margin = int(w * 0.085)
    y = int(h * 0.08)
    y = draw_block(d, title, font("bold", int(w * 0.082), lang), WHITE,
                   margin, y, w - 2 * margin, lang, align="center", leading=1.1,
                   stroke=2 if lang == "zh" else 0, stroke_fill=WHITE)
    y += int(h * 0.03)
    card_x = margin
    card_w = w - 2 * margin
    card_h = int(h * 0.135)
    gap = int(h * 0.028)
    tf = font("semibold", int(w * 0.05), lang)
    df = font("regular", int(w * 0.033), lang)
    for i, (t, s) in enumerate(items):
        yy = y + i * (card_h + gap)
        d.rounded_rectangle([card_x, yy, card_x + card_w, yy + card_h],
                            radius=int(w * 0.05), fill=CARD, outline=CARD_BORDER, width=2)
        # accent square with number
        sq = int(card_h * 0.56)
        sx = card_x + int(w * 0.05)
        sy = yy + (card_h - sq) // 2
        d.rounded_rectangle([sx, sy, sx + sq, sy + sq], radius=int(sq * 0.28), fill=SKY_DEEP)
        d.text((sx + sq / 2, sy + sq / 2), str(i + 1),
               font=font("bold", int(sq * 0.55)), fill=(8, 20, 30), anchor="mm")
        tx = sx + sq + int(w * 0.05)
        d.text((tx, yy + card_h * 0.30), t, font=tf, fill=WHITE, anchor="lm")
        d.text((tx, yy + card_h * 0.66), s, font=df, fill=MUTED, anchor="lm")
    wordmark(canvas, w / 2, h * 0.945, lang, scale=w / 1290 * 0.9)
    return canvas.convert("RGB")


def feature_graphic(lang):
    w, h = 1024, 500
    canvas = gradient_bg(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    isz = 300
    ic = load_icon(isz)
    ix, iy = 70, (h - isz) // 2
    drop_shadow(canvas, [ix, iy, ix + isz, iy + isz], int(isz * 0.23), 30, alpha=150)
    canvas.alpha_composite(ic.convert("RGBA"), (ix, iy))
    tx = ix + isz + 60
    avail = w - tx - 48  # right padding

    def fit(text, weight, start, lang):
        sz = start
        while sz > 12 and d.textlength(text, font=font(weight, sz, lang)) > avail:
            sz -= 2
        return font(weight, sz, lang)

    d.text((tx, 150), "ZRemote", font=fit("ZRemote", "bold", 120, "en"), fill=WHITE, anchor="lm")
    sub = {"en": "Remote for ZCode agents", "zh": "ZCode \u667a\u80fd\u4f53\u8fdc\u7a0b\u63a7\u5236"}[lang]
    d.text((tx, 258), sub, font=fit(sub, "semibold", 46, lang), fill=SKY, anchor="lm")
    tags = {"en": "Tasks \u00b7 Automations \u00b7 Off-peak \u00b7 Notifications",
            "zh": "\u4efb\u52a1 \u00b7 \u81ea\u52a8\u5316 \u00b7 \u95f2\u65f6 \u00b7 \u901a\u77e5"}[lang]
    d.text((tx, 322), tags, font=fit(tags, "medium", 32, lang), fill=MUTED, anchor="lm")
    return canvas.convert("RGB")


def ensure(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def main():
    s_tasks = os.path.join(SHOTS, "01-list-mobile.png")
    s_chat = os.path.join(SHOTS, "02-chat-mobile.png")
    s_dual = os.path.join(SHOTS, "03-dual-pane.png")

    # ── icons ──
    load_icon(1024).convert("RGB").save(
        ensure(os.path.join(OUT, "appstore/icon/app-icon-1024.png")))
    load_icon(512).convert("RGB").save(
        ensure(os.path.join(OUT, "googleplay/icon/play-icon-512.png")))

    # ── feature graphics ──
    for lang in ("en", "zh"):
        feature_graphic(lang).save(
            ensure(os.path.join(OUT, f"googleplay/feature-graphic/feature-graphic-{lang}.png")))

    # ── App Store iPhone 6.9" (1290x2796) ──
    W, H = 1290, 2796
    for lang in ("en", "zh"):
        hero_slide(W, H, lang).save(ensure(os.path.join(OUT, f"appstore/screenshots/iphone-6.9/00-hero-{lang}.png")))
        showcase_portrait(W, H, s_tasks, "tasks", lang).save(os.path.join(OUT, f"appstore/screenshots/iphone-6.9/01-tasks-{lang}.png"))
        showcase_portrait(W, H, s_chat, "conversation", lang).save(os.path.join(OUT, f"appstore/screenshots/iphone-6.9/02-conversation-{lang}.png"))
        features_slide(W, H, lang).save(os.path.join(OUT, f"appstore/screenshots/iphone-6.9/03-features-{lang}.png"))

    # ── App Store iPad 13" (2752x2064) ──
    W, H = 2752, 2064
    for lang in ("en", "zh"):
        showcase_landscape(W, H, s_dual, "dualpane", lang).save(
            ensure(os.path.join(OUT, f"appstore/screenshots/ipad-13/01-dualpane-{lang}.png")))

    # ── Google Play phone (1080x2400) ──
    W, H = 1080, 2400
    for lang in ("en", "zh"):
        hero_slide(W, H, lang).save(ensure(os.path.join(OUT, f"googleplay/screenshots/phone/00-hero-{lang}.png")))
        showcase_portrait(W, H, s_tasks, "tasks", lang).save(os.path.join(OUT, f"googleplay/screenshots/phone/01-tasks-{lang}.png"))
        showcase_portrait(W, H, s_chat, "conversation", lang).save(os.path.join(OUT, f"googleplay/screenshots/phone/02-conversation-{lang}.png"))
        features_slide(W, H, lang).save(os.path.join(OUT, f"googleplay/screenshots/phone/03-features-{lang}.png"))

    # ── Google Play tablet (1920x1200) ──
    W, H = 1920, 1200
    for lang in ("en", "zh"):
        showcase_landscape(W, H, s_dual, "dualpane", lang).save(
            ensure(os.path.join(OUT, f"googleplay/screenshots/tablet/01-dualpane-{lang}.png")))

    print("Store assets written to", OUT)


if __name__ == "__main__":
    main()
