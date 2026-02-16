import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compression settings for adaptive image compression
class _CompressionSettings {
  final int quality;
  final int maxDimension;

  const _CompressionSettings({
    required this.quality,
    required this.maxDimension,
  });
}

/// Media service for handling photo uploads to Firebase Storage.
/// Matches React Native postService uploadPostPhoto and storage rules.
class MediaService {
  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;

  MediaService(this._storage, this._imagePicker);

  // Size limits
  static const int maxPhotoSize = 5 * 1024 * 1024; // 5MB (reduced per plan)
  static const int maxVideoSize = 20 * 1024 * 1024; // 20MB
  static const int maxVoiceNoteSize = 5 * 1024 * 1024; // 5MB

  // Allowed file extensions
  static const List<String> allowedPhotoExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedVideoExtensions = ['mp4', 'mov'];
  static const List<String> allowedVoiceExtensions = [
    'm4a',
    'aac',
    'wav',
    'mp3',
  ];

  /// Validate file extension.
  static bool isValidPhotoExtension(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return allowedPhotoExtensions.contains(ext);
  }

  /// Validate video extension.
  static bool isValidVideoExtension(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return allowedVideoExtensions.contains(ext);
  }

  /// Validate voice note extension.
  static bool isValidVoiceExtension(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return allowedVoiceExtensions.contains(ext);
  }

  /// Check image dimensions and size, compress if necessary.
  /// Uses adaptive compression strategy:
  /// - Images < 1MB: 90% quality, max 2048px
  /// - Images 1-3MB: 85% quality, max 2048px
  /// - Images > 3MB: 80% quality, max 1920px
  Future<File> checkAndCompressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final width = frameInfo.image.width;
      final height = frameInfo.image.height;
      final fileSizeBytes = await file.length();
      final fileSizeMB = fileSizeBytes / (1024 * 1024);

      // Determine compression settings based on file size
      final compressionSettings = _getCompressionSettings(fileSizeMB);

      // Check if compression is needed
      final needsDimensionResize =
          width > compressionSettings.maxDimension ||
          height > compressionSettings.maxDimension;
      final needsSizeReduction = fileSizeMB > 0.5; // Compress if over 500KB

      if (!needsDimensionResize && !needsSizeReduction) {
        debugPrint(
          '[MediaService] Image ($width x $height, ${fileSizeMB.toStringAsFixed(2)}MB) - no compression needed',
        );
        return file;
      }

      debugPrint(
        '[MediaService] Compressing image ($width x $height, ${fileSizeMB.toStringAsFixed(2)}MB) '
        'with quality ${compressionSettings.quality}%, max ${compressionSettings.maxDimension}px',
      );

      final dir = file.parent.path;
      final name = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = '$dir/$name';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: compressionSettings.maxDimension,
        minHeight: compressionSettings.maxDimension,
        quality: compressionSettings.quality,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        final compressedSize = await compressedFile.length();
        final savedMB = (fileSizeBytes - compressedSize) / (1024 * 1024);
        final savedPercent =
            (fileSizeBytes - compressedSize) / fileSizeBytes * 100;

        debugPrint(
          '[MediaService] Compression complete: '
          '${fileSizeMB.toStringAsFixed(2)}MB → ${(compressedSize / (1024 * 1024)).toStringAsFixed(2)}MB '
          '(saved ${savedMB.toStringAsFixed(2)}MB / ${savedPercent.toStringAsFixed(1)}%)',
        );

        return compressedFile;
      }

      return file;
    } catch (e) {
      debugPrint('[MediaService] Compression failed: $e');
      // If compression fails, return original file but log warning
      return file;
    }
  }

  /// Get compression settings based on file size
  _CompressionSettings _getCompressionSettings(double fileSizeMB) {
    if (fileSizeMB < 1.0) {
      // Small images: high quality, standard dimensions
      return const _CompressionSettings(quality: 90, maxDimension: 2048);
    } else if (fileSizeMB < 3.0) {
      // Medium images: balanced quality
      return const _CompressionSettings(quality: 85, maxDimension: 2048);
    } else {
      // Large images: more aggressive compression
      return const _CompressionSettings(quality: 80, maxDimension: 1920);
    }
  }

  /// Pick an image from gallery or camera.
  /// Optimized with maxWidth/maxHeight and checks via helper.
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (picked != null) {
        // Double check compression
        final file = File(picked.path);
        final processed = await checkAndCompressImage(file);
        return XFile(processed.path);
      }
      return null;
    } catch (e) {
      debugPrint('[MediaService] Error picking image: $e');
      return null;
    }
  }

  /// Upload a post photo to Firebase Storage.
  /// Matches RN uploadPostPhoto behavior.
  /// Uses putFile for efficient streaming with retry logic.
  ///
  /// Throws specific exceptions:
  /// - Network errors: "Network connection lost..."
  /// - Permission errors: "Storage permission denied..."
  /// - File size errors: "Photo exceeds 5MB limit..."
  /// - Format errors: "Invalid file format..."
  Future<String> uploadPostPhoto({
    required String filePath,
    required String postId,
    void Function(double)? onProgress,
    int maxRetries = 3,
  }) async {
    // Validate file extension
    if (!isValidPhotoExtension(filePath)) {
      throw Exception('Invalid file format. Only JPG and PNG are supported.');
    }

    final file = File(filePath);

    // Check if file exists
    if (!await file.exists()) {
      throw Exception('Photo file not found. Please select a new photo.');
    }

    final length = await file.length();

    // Validate file size
    if (length > maxPhotoSize) {
      throw Exception(
        'Photo exceeds 5MB limit. Please choose a smaller photo.',
      );
    }

    final filename =
        'posts/$postId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = _storage.ref(filename);

    // Retry logic with exponential backoff
    Exception? lastError;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint(
            '[MediaService] Retrying upload (${attempt + 1}/$maxRetries)...',
          );
        }
        onProgress?.call(0.0);

        // Upload with progress tracking using putFile (streams data)
        final uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        uploadTask.snapshotEvents.listen((event) {
          // Emit raw 0-1 progress - caller handles any scaling
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress?.call(progress);
        });

        await uploadTask;
        onProgress?.call(1.0);

        return await storageRef.getDownloadURL();
      } on FirebaseException catch (e) {
        lastError = _mapFirebaseError(e);
        debugPrint('[MediaService] Upload attempt ${attempt + 1} failed: $e');

        if (attempt < maxRetries - 1) {
          // Exponential backoff: 1s, 2s, 4s
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      } catch (e) {
        lastError = _mapGenericError(e);
        debugPrint('[MediaService] Upload attempt ${attempt + 1} failed: $e');

        if (attempt < maxRetries - 1) {
          // Exponential backoff: 1s, 2s, 4s
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }

    throw lastError ??
        Exception(
          'Upload failed after $maxRetries attempts. Please check your connection and try again.',
        );
  }

  /// Map Firebase exceptions to user-friendly error messages
  Exception _mapFirebaseError(FirebaseException e) {
    final code = e.code.toLowerCase();

    if (code.contains('network') || code.contains('unavailable')) {
      return Exception(
        'Network connection lost. Please check your internet and try again.',
      );
    } else if (code.contains('unauthorized') || code.contains('permission')) {
      return Exception(
        'Storage permission denied. Please enable storage access in settings.',
      );
    } else if (code.contains('quota') || code.contains('exceeded')) {
      return Exception('Storage quota exceeded. Please try again later.');
    } else if (code.contains('canceled') || code.contains('cancelled')) {
      return Exception('Upload was cancelled. Please try again.');
    } else if (code.contains('retry') || code.contains('timeout')) {
      return Exception(
        'Upload timed out. Please check your connection and try again.',
      );
    }

    return Exception('Upload failed: ${e.message}');
  }

  /// Map generic errors to user-friendly messages
  Exception _mapGenericError(dynamic e) {
    final errorStr = e.toString().toLowerCase();

    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket')) {
      return Exception(
        'Network connection lost. Please check your internet and try again.',
      );
    } else if (errorStr.contains('permission')) {
      return Exception(
        'Storage permission denied. Please enable storage access in settings.',
      );
    } else if (errorStr.contains('no space') || errorStr.contains('disk')) {
      return Exception(
        'Not enough storage space. Please free up some space and try again.',
      );
    }

    return e is Exception ? e : Exception(e.toString());
  }

  /// Upload a user profile photo.
  /// Uses retry logic with exponential backoff for reliability.
  Future<String> uploadProfilePhoto({
    required String filePath,
    required String userId,
    void Function(double)? onProgress,
    int maxRetries = 3,
  }) async {
    // Validate file extension
    if (!isValidPhotoExtension(filePath)) {
      throw Exception(
        'Invalid file type. Only JPG and PNG photos are allowed.',
      );
    }

    // Compress/Resize if needed
    final originalFile = File(filePath);
    final file = await checkAndCompressImage(originalFile);
    final length = await file.length();

    if (length > maxPhotoSize) {
      throw Exception(
        'Photo exceeds maximum size of ${maxPhotoSize ~/ (1024 * 1024)}MB. Please choose a smaller photo or compress it.',
      );
    }

    final filename =
        'profilePhotos/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = _storage.ref(filename);

    // Retry logic with exponential backoff
    Exception? lastError;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        onProgress?.call(0.1);

        final uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        uploadTask.snapshotEvents.listen((event) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress?.call(0.1 + progress * 0.8);
        });

        await uploadTask;
        onProgress?.call(1.0);

        return await storageRef.getDownloadURL();
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint(
          '[MediaService] Profile photo upload attempt ${attempt + 1} failed: $e',
        );

        if (attempt < maxRetries - 1) {
          // Exponential backoff: 1s, 2s, 4s
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }

    throw lastError ??
        Exception(
          'Profile photo upload failed after $maxRetries attempts. Please check your connection and try again.',
        );
  }

  /// Upload a voice note for session.
  /// Matches RN uploadVoiceNote behavior.
  Future<String> uploadVoiceNote({
    required String filePath,
    required String sessionId,
    void Function(double)? onProgress,
  }) async {
    // Validate file extension
    if (!isValidVoiceExtension(filePath)) {
      throw Exception(
        'Invalid file type. Only M4A, AAC, WAV, and MP3 audio files are allowed.',
      );
    }

    final file = File(filePath);
    final length = await file.length();

    if (length > maxVoiceNoteSize) {
      throw Exception(
        'Voice note exceeds maximum size of ${maxVoiceNoteSize ~/ (1024 * 1024)}MB',
      );
    }

    final filename =
        'voiceNotes/$sessionId/${DateTime.now().millisecondsSinceEpoch}.m4a';
    final storageRef = _storage.ref(filename);

    onProgress?.call(0.1);

    final uploadTask = storageRef.putFile(
      file,
      SettableMetadata(contentType: 'audio/mp4'),
    );

    uploadTask.snapshotEvents.listen((event) {
      final progress = event.bytesTransferred / event.totalBytes;
      onProgress?.call(0.1 + progress * 0.8);
    });

    await uploadTask;
    onProgress?.call(1.0);

    return await storageRef.getDownloadURL();
  }

  /// Upload bytes directly (for web/cross-platform).
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
    void Function(double)? onProgress,
  }) async {
    final storageRef = _storage.ref(path);

    onProgress?.call(0.1);

    final uploadTask = storageRef.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    uploadTask.snapshotEvents.listen((event) {
      final progress = event.bytesTransferred / event.totalBytes;
      onProgress?.call(0.1 + progress * 0.8);
    });

    await uploadTask;
    onProgress?.call(1.0);

    return await storageRef.getDownloadURL();
  }
}

/// Media service provider.
final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(FirebaseStorage.instance, ImagePicker());
});
