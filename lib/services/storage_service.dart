import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  Future<List<String>> uploadImages(List<XFile> images) async {
    return _uploadFiles(
      files: images,
      folder: 'post_images',
      extensionFallback: 'jpg',
      contentType: 'image/jpeg',
    );
  }

  Future<String> uploadVoiceNote(String path) async {
    final urls = await _uploadFiles(
      files: [XFile(path)],
      folder: 'voice_notes',
      extensionFallback: 'm4a',
      contentType: 'audio/m4a',
    );
    return urls.first;
  }

  Future<List<String>> _uploadFiles({
    required List<XFile> files,
    required String folder,
    required String extensionFallback,
    required String contentType,
  }) async {
    final List<String> urls = [];

    for (final file in files) {
      final String fileName =
          '${_uuid.v4()}.${_resolveExtension(file.path, extensionFallback)}';
      final Reference ref = _storage.ref().child(folder).child(fileName);

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: contentType));
      } else {
        await ref.putFile(
          File(file.path),
          SettableMetadata(contentType: contentType),
        );
      }

      final String url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  String _resolveExtension(String path, String fallback) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return fallback;
    }
    return path.substring(dotIndex + 1);
  }
}
