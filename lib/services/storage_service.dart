import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class StorageService {
  // Private constructor
  StorageService._internal();

  // Singleton instance
  static final StorageService _instance = StorageService._internal();

  // Factory constructor
  factory StorageService() => _instance;

  /// Detects the content type from image bytes by checking magic bytes
  String _detectContentType(Uint8List bytes) {
    if (bytes.length < 12) return 'image/jpeg'; // Default fallback

    // Check for JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // Check for PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    // Check for GIF: GIF87a or GIF89a
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'image/gif';
    }

    // Check for WebP: RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes.length > 11 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    // Check for HEIC/HEIF: ftyp followed by heic, heix, mif1, etc.
    if (bytes.length > 11 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return 'image/heic';
    }

    // Default to JPEG if unknown
    return 'image/jpeg';
  }

  /// This is used as a workaround when Firebase Storage is not available.
  /// Note: Firestore documents have a 1MB limit.
  Future<String?> uploadReceipt({
    required String userId,
    File? file,
    Uint8List? bytes,
    String? extension,
  }) async {
    try {
      // Read bytes if we have a file but no bytes
      Uint8List? imageBytes = bytes;
      if (imageBytes == null && file != null) {
        imageBytes = await file.readAsBytes();
      }

      if (imageBytes == null) {
        throw Exception('Either file or bytes are required for upload');
      }

      // Detect content type from bytes
      final String contentType = _detectContentType(imageBytes);

      // Check size (Firestore limit is 1MB, let's keep it under 800KB for safety)
      final int sizeInBytes = imageBytes.length;
      if (sizeInBytes > 900 * 1024) {
        debugPrint(
          'WARNING: Image size ($sizeInBytes bytes) is close to Firestore 1MB limit.',
        );
      }

      debugPrint(
        'Converting image to Base64 - Content-Type: $contentType, Size: $sizeInBytes bytes',
      );

      // Convert to Base64
      final String base64String = base64Encode(imageBytes);
      final String dataUrl = 'data:$contentType;base64,$base64String';

      debugPrint(
        'Base64 conversion complete. String length: ${dataUrl.length}',
      );

      return dataUrl;
    } catch (e, stackTrace) {
      debugPrint('Error converting receipt to Base64: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}
