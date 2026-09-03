import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class NormalizedImage {
  final File file;
  final int width;
  final int height;

  const NormalizedImage({
    required this.file,
    required this.width,
    required this.height,
  });

  double get aspectRatio => width / height;
}

class ImageOrientationService {
  static Future<NormalizedImage> normalize(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unable to decode image');
    }

    final oriented = img.bakeOrientation(decoded);
    final directory = await getTemporaryDirectory();
    final output = File(
      '${directory.path}/kronocam_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final encoded = img.encodeJpg(oriented, quality: 95);
    await output.writeAsBytes(Uint8List.fromList(encoded), flush: true);

    return NormalizedImage(
      file: output,
      width: oriented.width,
      height: oriented.height,
    );
  }
}
