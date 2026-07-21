import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image to Firebase Storage and return the download URL
  /// Returns null if upload fails
  static Future<String?> uploadImage(
    Uint8List imageBytes, {
    String folder = 'images',
    int retryCount = 2,
  }) async {
    for (int attempt = 0; attempt <= retryCount; attempt++) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          print('❌ User not authenticated');
          return null;
        }

        // Generate unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${user.uid}_${timestamp}_$attempt.jpg';
        final path = '$folder/$fileName';

        print(
          '🔄 Uploading image to Firebase Storage (attempt ${attempt + 1}/${retryCount + 1})...',
        );
        print('📂 Path: $path');

        // Create reference
        final ref = _storage.ref().child(path);

        // Upload with metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        // Upload the file
        final uploadTask = ref.putData(imageBytes, metadata);

        // Monitor progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('📊 Upload progress: ${progress.toStringAsFixed(1)}%');
        });

        // Wait for completion
        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            throw Exception('Upload timeout after 120 seconds');
          },
        );

        // Get download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('✅ Image uploaded successfully: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        print(
          '❌ Error uploading to Firebase Storage (attempt ${attempt + 1}/${retryCount + 1}): $e',
        );
        print('   Error type: ${e.runtimeType}');

        // Retry on network errors
        if (attempt < retryCount) {
          final waitSeconds = (attempt + 1) * 2;
          print('⏳ Retrying in $waitSeconds seconds...');
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
        print('💥 All retry attempts exhausted. Upload failed.');
        return null;
      }
    }

    return null;
  }

  /// Upload image with UI progress callbacks and a configurable timeout.
  /// This is useful for screens where a silent 120s Firebase wait feels stuck.
  static Future<String?> uploadImageWithProgress(
    Uint8List imageBytes, {
    String folder = 'images',
    int retryCount = 1,
    Duration timeout = const Duration(seconds: 60),
    void Function(double progress)? onProgress,
    void Function(int attempt, int maxAttempts)? onAttempt,
  }) async {
    final maxAttempts = retryCount + 1;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      StreamSubscription<TaskSnapshot>? subscription;

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          print('❌ User not authenticated');
          return null;
        }

        onAttempt?.call(attempt + 1, maxAttempts);

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${user.uid}_${timestamp}_$attempt.jpg';
        final path = '$folder/$fileName';
        final ref = _storage.ref().child(path);
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        print(
          '🔄 Uploading image to Firebase Storage (attempt ${attempt + 1}/$maxAttempts)...',
        );
        print('📂 Path: $path');
        print('📦 Size: ${(imageBytes.length / 1024).toStringAsFixed(1)} KB');

        final uploadTask = ref.putData(imageBytes, metadata);
        subscription = uploadTask.snapshotEvents.listen((snapshot) {
          final totalBytes = snapshot.totalBytes;
          if (totalBytes <= 0) return;
          final progress = snapshot.bytesTransferred / totalBytes;
          onProgress?.call(progress.clamp(0.0, 1.0));
        });

        final snapshot = await uploadTask.timeout(
          timeout,
          onTimeout: () async {
            await uploadTask.cancel();
            throw TimeoutException(
              'Upload timeout after ${timeout.inSeconds} seconds',
            );
          },
        );

        onProgress?.call(1.0);
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('✅ Image uploaded successfully: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        print(
          '❌ Error uploading to Firebase Storage (attempt ${attempt + 1}/$maxAttempts): $e',
        );
        print('   Error type: ${e.runtimeType}');

        if (attempt < retryCount) {
          final waitSeconds = attempt + 2;
          print('⏳ Retrying in $waitSeconds seconds...');
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }

        print('💥 All retry attempts exhausted. Upload failed.');
        return null;
      } finally {
        await subscription?.cancel();
      }
    }

    return null;
  }

  /// Upload multiple images and return list of URLs
  /// Returns empty list if all uploads fail
  static Future<List<String>> uploadMultipleImages(
    List<Uint8List> imageBytesList, {
    String folder = 'images',
  }) async {
    List<String> urls = [];

    for (int i = 0; i < imageBytesList.length; i++) {
      print('Uploading image ${i + 1}/${imageBytesList.length}');
      final url = await uploadImage(imageBytesList[i], folder: folder);
      if (url != null) {
        urls.add(url);
      } else {
        print('Failed to upload image ${i + 1}');
      }
    }

    return urls;
  }

  /// Delete image from Firebase Storage
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(imageUrl);
      if (!uri.host.contains('firebasestorage.googleapis.com')) {
        print('Not a Firebase Storage URL');
        return false;
      }

      // Get reference from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Image deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Delete multiple images from Firebase Storage
  static Future<void> deleteMultipleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImage(url);
    }
  }
}
