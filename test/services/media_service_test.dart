import 'package:flutter_test/flutter_test.dart';

import 'package:zyntro_flutter/services/media_service.dart';

void main() {
  group('isValidPhotoExtension', () {
    test('accepts the allowed photo formats', () {
      for (final ext in MediaService.allowedPhotoExtensions) {
        expect(
          MediaService.isValidPhotoExtension('/tmp/photo.$ext'),
          isTrue,
          reason: ext,
        );
      }
    });

    test('is case-insensitive', () {
      // A camera roll file can arrive as IMG_0001.JPG.
      expect(MediaService.isValidPhotoExtension('/tmp/IMG_0001.JPG'), isTrue);
      expect(MediaService.isValidPhotoExtension('/tmp/photo.PNG'), isTrue);
    });

    test('rejects a video or audio file', () {
      expect(MediaService.isValidPhotoExtension('/tmp/clip.mp4'), isFalse);
      expect(MediaService.isValidPhotoExtension('/tmp/note.m4a'), isFalse);
    });

    test('rejects an executable disguised by name', () {
      expect(MediaService.isValidPhotoExtension('/tmp/photo.jpg.exe'), isFalse);
      expect(MediaService.isValidPhotoExtension('/tmp/evil.sh'), isFalse);
    });

    test('rejects a file with no extension', () {
      expect(MediaService.isValidPhotoExtension('/tmp/photo'), isFalse);
      expect(MediaService.isValidPhotoExtension(''), isFalse);
    });

    test('reads the extension, not an earlier dot in the path', () {
      expect(
        MediaService.isValidPhotoExtension('/tmp/my.photos/shot.png'),
        isTrue,
      );
      expect(
        MediaService.isValidPhotoExtension('/tmp/my.png.folder/shot.exe'),
        isFalse,
      );
    });
  });

  group('isValidVideoExtension', () {
    test('accepts the allowed video formats', () {
      for (final ext in MediaService.allowedVideoExtensions) {
        expect(
          MediaService.isValidVideoExtension('/tmp/clip.$ext'),
          isTrue,
          reason: ext,
        );
      }
    });

    test('rejects a photo', () {
      expect(MediaService.isValidVideoExtension('/tmp/photo.jpg'), isFalse);
    });
  });

  group('isValidVoiceExtension', () {
    test('accepts the allowed audio formats', () {
      for (final ext in MediaService.allowedVoiceExtensions) {
        expect(
          MediaService.isValidVoiceExtension('/tmp/note.$ext'),
          isTrue,
          reason: ext,
        );
      }
    });

    test('rejects a photo or video', () {
      expect(MediaService.isValidVoiceExtension('/tmp/photo.jpg'), isFalse);
      expect(MediaService.isValidVoiceExtension('/tmp/clip.mp4'), isFalse);
    });
  });

  group('the three allow-lists stay disjoint', () {
    test('no extension is valid for more than one media kind', () {
      // An overlap would let a file pass a check meant for a different kind,
      // and the storage rules are written per media type.
      final all = [
        ...MediaService.allowedPhotoExtensions,
        ...MediaService.allowedVideoExtensions,
        ...MediaService.allowedVoiceExtensions,
      ];

      expect(all.toSet(), hasLength(all.length));
    });

    test('every allow-listed extension is lowercase', () {
      // The validators lowercase the input before comparing, so an uppercase
      // entry here would be unmatchable.
      final all = [
        ...MediaService.allowedPhotoExtensions,
        ...MediaService.allowedVideoExtensions,
        ...MediaService.allowedVoiceExtensions,
      ];

      for (final ext in all) {
        expect(ext, ext.toLowerCase(), reason: ext);
      }
    });
  });

  group('size limits', () {
    test('photos cap at 5MB', () {
      expect(MediaService.maxPhotoSize, 5 * 1024 * 1024);
    });

    test('videos cap at 20MB', () {
      expect(MediaService.maxVideoSize, 20 * 1024 * 1024);
    });

    test('voice notes cap at 5MB', () {
      expect(MediaService.maxVoiceNoteSize, 5 * 1024 * 1024);
    });

    test('a video may be larger than a photo', () {
      expect(
        MediaService.maxVideoSize,
        greaterThan(MediaService.maxPhotoSize),
      );
    });
  });
}
