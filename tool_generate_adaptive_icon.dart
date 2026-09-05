import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() {
  const s = 1024;
  final fg = img.Image(width: s, height: s, numChannels: 4);
  final bg = img.Image(width: s, height: s, numChannels: 4);
  final dark = img.ColorRgba8(0x0E, 0x0E, 0x10, 255);
  final transparent = img.ColorRgba8(0, 0, 0, 0);
  final gun = img.ColorRgba8(0x3C, 0x3C, 0x3C, 255);
  final steel = img.ColorRgba8(0xB9, 0xC0, 0xC5, 255);
  final green = img.ColorRgba8(0x2F, 0xD6, 0x75, 255);
  final blue = img.ColorRgba8(0x26, 0xB8, 0xEE, 255);
  final violet = img.ColorRgba8(0x8E, 0x4B, 0xE4, 255);
  final white = img.ColorRgba8(255, 255, 255, 255);
  img.fill(bg, color: dark);
  img.fill(fg, color: transparent);
  img.fillCircle(fg, x: 512, y: 512, radius: 316, color: gun);
  img.drawCircle(
    fg,
    x: 512,
    y: 512,
    radius: 316,
    color: steel,
    antialias: true,
  );
  img.fillCircle(fg, x: 512, y: 512, radius: 286, color: dark);
  for (var r = 272; r >= 220; r -= 10) {
    final t = (272 - r) / 52;
    img.fillCircle(
      fg,
      x: 512,
      y: 512,
      radius: r,
      color: img.ColorRgba8(
        (60 - 35 * t).round(),
        (60 - 35 * t).round(),
        (60 - 35 * t).round(),
        255,
      ),
    );
  }
  img.fillCircle(fg, x: 512, y: 512, radius: 212, color: blue);
  img.fillCircle(fg, x: 512, y: 512, radius: 198, color: violet);
  img.fillCircle(fg, x: 512, y: 512, radius: 184, color: blue);
  img.fillCircle(fg, x: 512, y: 512, radius: 166, color: dark);
  img.fillCircle(
    fg,
    x: 512,
    y: 512,
    radius: 153,
    color: img.ColorRgba8(18, 40, 74, 255),
  );
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6 - math.pi / 2;
    final l = i % 3 == 0 ? 20 : 11;
    img.drawLine(
      fg,
      x1: (512 + math.cos(a) * (116 - l)).round(),
      y1: (512 + math.sin(a) * (116 - l)).round(),
      x2: (512 + math.cos(a) * 116).round(),
      y2: (512 + math.sin(a) * 116).round(),
      color: white,
      thickness: i % 3 == 0 ? 6 : 3,
      antialias: true,
    );
  }
  final ten = -math.pi / 3;
  final two = math.pi / 6;
  img.drawLine(
    fg,
    x1: 512,
    y1: 512,
    x2: (512 + math.cos(ten) * 76).round(),
    y2: (512 + math.sin(ten) * 76).round(),
    color: steel,
    thickness: 10,
    antialias: true,
  );
  img.drawLine(
    fg,
    x1: 512,
    y1: 512,
    x2: (512 + math.cos(two) * 88).round(),
    y2: (512 + math.sin(two) * 88).round(),
    color: steel,
    thickness: 8,
    antialias: true,
  );
  img.fillCircle(fg, x: 512, y: 512, radius: 11, color: white);
  img.fillCircle(fg, x: 512, y: 512, radius: 5, color: green);
  img.drawCircle(fg, x: 512, y: 512, radius: 278, color: gun, antialias: true);
  img.drawCircle(
    fg,
    x: 512,
    y: 512,
    radius: 257,
    color: steel,
    antialias: true,
  );
  img.drawCircle(fg, x: 512, y: 512, radius: 223, color: gun, antialias: true);
  // Keep the foreground inside the adaptive icon safe zone. Launcher masks
  // can crop artwork near the edge even when the source image is square.
  final safeForeground = img.Image(width: s, height: s, numChannels: 4);
  img.fill(safeForeground, color: transparent);
  final paddedForeground = img.copyResize(
    fg,
    width: 800,
    height: 800,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(safeForeground, paddedForeground, dstX: 112, dstY: 112);
  final flattened = img.Image.from(bg);
  img.compositeImage(flattened, safeForeground);
  File(
    'assets/icons/app_icon_foreground.png',
  ).writeAsBytesSync(img.encodePng(safeForeground));
  File(
    'assets/icons/app_icon_background.png',
  ).writeAsBytesSync(img.encodePng(bg));
  File('assets/icons/app_icon.png').writeAsBytesSync(img.encodePng(flattened));
}
