import 'dart:typed_data';

import 'package:gal/gal.dart';

class GalleryService {
  static const _album = 'KronoCam';

  static Future<bool> hasAccess() => Gal.hasAccess();

  static Future<bool> requestAccess() => Gal.requestAccess();

  /// Saves raw PNG/JPEG bytes to the device gallery under the KronoCam
  /// album. Returns true on success.
  static Future<bool> saveBytes(Uint8List bytes, {String? name}) async {
    try {
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) return false;
      }
      await Gal.putImageBytes(
        bytes,
        album: _album,
        name: name ?? 'KronoCam_${DateTime.now().millisecondsSinceEpoch}',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
