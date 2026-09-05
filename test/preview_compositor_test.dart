import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kronocam/screens/preview_editor_screen.dart';

void main() {
  test('preview compositor preserves the source dimensions and position', () {
    final photo = img.Image(width: 100, height: 60);
    img.fill(photo, color: img.ColorRgb8(20, 20, 20));
    final overlay = img.Image(width: 10, height: 6);
    img.fill(overlay, color: img.ColorRgba8(240, 20, 20, 255));

    final output = compositePreviewInIsolate({
      'photo': Uint8List.fromList(img.encodePng(photo)),
      'overlay': Uint8List.fromList(img.encodePng(overlay)),
      'displayWidth': 50.0,
      'pixelRatio': 1.0,
      'boxScale': 1.0,
      'rotation': 0.35,
      'ratioX': 0.5,
      'ratioY': 0.5,
    });
    final result = img.decodeImage(output)!;

    expect(result.width, 100);
    expect(result.height, 60);
    var redPixels = 0;
    for (final pixel in result) {
      if (pixel.r > 200 && pixel.g < 80 && pixel.b < 80) redPixels++;
    }
    expect(redPixels, greaterThan(10));
  });
}
