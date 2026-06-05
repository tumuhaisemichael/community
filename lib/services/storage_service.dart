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
    final List<String> urls = [];

    for (final image in images) {
      final String fileName = '${_uuid.v4()}.jpg';
      final Reference ref = _storage.ref().child('post_images').child(fileName);

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        await ref.putFile(File(image.path));
      }

      final String url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }
}
