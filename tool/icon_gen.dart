// Generates the ZRemote launcher icon set:
//   assets/icon/icon.png      – full-bleed 1024 icon (iOS + legacy Android)
//   assets/icon/icon_fg.png   – transparent foreground for Android adaptive icons
//
// Style follows the official ZCode app icon: flat dark background, a bold
// geometric white "Z", plus a sky-blue broadcast accent for "remote".
//
// Run: dart run tool/icon_gen.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

final _bg = ColorRgb8(0x16, 0x16, 0x16); // official dark background
final _white = ColorRgb8(0xFF, 0xFF, 0xFF);
final _sky = ColorRgb8(0x0E, 0xA5, 0xE9); // official sky-500

void main() {
  Directory('assets/icon').create(recursive: true);
  encodePngFile('assets/icon/icon.png', _paint(1024, 0.40, opaque: true));
  encodePngFile('assets/icon/icon_fg.png', _paint(1024, 0.30, opaque: false));
  stdout.writeln('icons written to assets/icon/');
}

Image _paint(int size, double glyphScale, {required bool opaque}) {
  final img = Image(width: size, height: size);
  if (opaque) fill(img, color: _bg);

  final s = size * glyphScale; // glyph baseline box height
  final zw = s * 1.30; // Z box: wide and short, like the official mark
  final t = s * 0.235; // uniform stroke thickness
  // Shift up-left so the broadcast accent has room in the bottom-right.
  final cx = size * 0.45;
  final cy = size * 0.44;
  final left = cx - zw / 2, right = cx + zw / 2;
  final top = cy - s / 2, bottom = cy + s / 2;

  // Top bar.
  fillRect(img,
      x1: left.round(),
      y1: top.round(),
      x2: right.round(),
      y2: (top + t).round(),
      color: _white);
  // Bottom bar.
  fillRect(img,
      x1: left.round(),
      y1: (bottom - t).round(),
      x2: right.round(),
      y2: bottom.round(),
      color: _white);
  // Diagonal: top-right → bottom-left, uniform-width parallelogram,
  // drawn with a scanline loop (image 4.x fillPolygon takes its own Point type).
  final d = t * 1.15;
  for (var y = top.round(); y <= bottom.round(); y++) {
    if (y < 0 || y >= size) continue;
    final k = (y - top) / (bottom - top);
    final x1 = (right - d) + k * (left - (right - d));
    final x2 = right + k * ((left + d) - right);
    for (var x = x1.round(); x <= x2.round(); x++) {
      if (x < 0 || x >= size) continue;
      img.setPixelRgba(x, y, _white.r, _white.g, _white.b, 255);
    }
  }

  // Broadcast accent: dot + two arcs radiating from the Z's bottom-right
  // corner toward the lower-right, in the official sky blue.
  final acx = right + s * 0.01;
  final acy = bottom + s * 0.01;
  final dotR = s * 0.052;
  final ring1 = s * 0.135;
  final ring2 = s * 0.215;
  final ringTh = s * 0.050;
  const halfBand = 38.0 * math.pi / 180; // ±38° around the 45° ray

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - acx;
      final dy = y - acy;
      final r = math.sqrt(dx * dx + dy * dy);
      final ang = math.atan2(dy, dx); // screen coords: 45° = down-right
      final inBand = (ang - math.pi / 4).abs() <= halfBand;
      if (r <= dotR || (inBand && ((r - ring1).abs() <= ringTh / 2 || (r - ring2).abs() <= ringTh / 2))) {
        img.setPixelRgba(x, y, _sky.r, _sky.g, _sky.b, 255);
      }
    }
  }
  return img;
}
