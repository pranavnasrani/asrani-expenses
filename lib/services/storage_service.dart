import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Stores receipt photos inline as data URLs (the project does not use
/// Firebase Storage). Firestore documents are capped at 1 MiB, so oversized
/// images are rejected rather than failing the whole expense write.
class StorageService {
  static const maxBytes = 700 * 1024;

  static String detectContentType(Uint8List bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }
    if (bytes.length >= 12 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  /// Returns a `data:` URL, or null when the image is too large to store.
  static String? toDataUrl(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      debugPrint('Receipt image is ${bytes.length} bytes; over the $maxBytes limit');
      return null;
    }
    return 'data:${detectContentType(bytes)};base64,${base64Encode(bytes)}';
  }

  static Uint8List? decodeDataUrl(String url) {
    if (!url.startsWith('data:')) return null;
    try {
      return base64Decode(url.substring(url.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }
}
