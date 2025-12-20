import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Private constructor
  StorageService._internal();

  // Singleton instance
  static final StorageService _instance = StorageService._internal();

  // Factory constructor
  factory StorageService() => _instance;

  /// Uploads a receipt image to Firebase Storage and returns the download URL.
  /// Uses [putFile] on mobile and [putData] on web.
  Future<String?> uploadReceipt({
    required String userId,
    File? file,
    Uint8List? bytes,
    String? extension,
  }) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}${extension ?? '.jpg'}';
      final Reference ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('receipts')
          .child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': userId},
      );

      UploadTask uploadTask;

      if (kIsWeb) {
        if (bytes == null) throw Exception('Bytes are required for web upload');
        uploadTask = ref.putData(bytes, metadata);
      } else {
        if (file == null) {
          // Fallback to putData if file is not provided but bytes are (e.g. from some pickers)
          if (bytes == null) {
            throw Exception('Either file or bytes are required for upload');
          }
          uploadTask = ref.putData(bytes, metadata);
        } else {
          uploadTask = ref.putFile(file, metadata);
        }
      }

      // Await completion and get snapshot
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading to Firebase Storage: $e');
      return null;
    }
  }
}
