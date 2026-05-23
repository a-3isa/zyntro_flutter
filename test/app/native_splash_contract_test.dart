import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('native splash configuration', () {
    test('uses the requested source assets', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(
        pubspec,
        contains('background_image: assets/splash_background.png'),
      );
      expect(pubspec, contains('image: assets/splash_z_v5.png'));
      expect(pubspec, contains('android_12:'));
      expect(File('assets/splash_background.png').existsSync(), isTrue);
      expect(File('assets/splash_z_v5.png').existsSync(), isTrue);
    });

    test('generates Android launch resources from the configured assets', () {
      final launchBackground =
          File('android/app/src/main/res/drawable/launch_background.xml')
              .readAsStringSync();
      final launchBackgroundV21 =
          File('android/app/src/main/res/drawable-v21/launch_background.xml')
              .readAsStringSync();
      final stylesV31 =
          File('android/app/src/main/res/values-v31/styles.xml')
              .readAsStringSync();
      final stylesNightV31 =
          File('android/app/src/main/res/values-night-v31/styles.xml')
              .readAsStringSync();

      for (final xml in [launchBackground, launchBackgroundV21]) {
        expect(xml, contains('@drawable/background'));
        expect(xml, contains('@drawable/splash'));
      }

      for (final xml in [stylesV31, stylesNightV31]) {
        expect(xml, contains('android:windowSplashScreenBackground'));
        expect(xml, contains('android:windowSplashScreenAnimatedIcon'));
        expect(xml, contains('@drawable/android12splash'));
      }

      expect(
        File('android/app/src/main/res/drawable/background.png')
            .readAsBytesSync(),
        File('assets/splash_background.png').readAsBytesSync(),
      );
      expect(
        File('android/app/src/main/res/drawable-v21/background.png')
            .readAsBytesSync(),
        File('assets/splash_background.png').readAsBytesSync(),
      );

      const expectedDensitySizes = {
        'mdpi': 256,
        'hdpi': 384,
        'xhdpi': 512,
        'xxhdpi': 768,
        'xxxhdpi': 1024,
      };

      for (final entry in expectedDensitySizes.entries) {
        expect(
          _pngSize(
            'android/app/src/main/res/drawable-${entry.key}/splash.png',
          ),
          (entry.value, entry.value),
        );
        expect(
          _pngSize(
            'android/app/src/main/res/drawable-${entry.key}/android12splash.png',
          ),
          (entry.value, entry.value),
        );
      }
    });

    test('generates iOS launch resources from the configured assets', () {
      final storyboard =
          File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
              .readAsStringSync();

      expect(storyboard, contains('image="LaunchBackground"'));
      expect(storyboard, contains('image="LaunchImage"'));
      expect(
        File('ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png')
            .readAsBytesSync(),
        File('assets/splash_background.png').readAsBytesSync(),
      );

      expect(
        _pngSize(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
        ),
        (256, 256),
      );
      expect(
        _pngSize(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png',
        ),
        (512, 512),
      );
      expect(
        _pngSize(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
        ),
        (768, 768),
      );
    });
  });
}

(int width, int height) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 24 || !_hasPngSignature(bytes)) {
    throw StateError('$path is not a valid PNG file');
  }

  return (_readBigEndianInt(bytes, 16), _readBigEndianInt(bytes, 20));
}

bool _hasPngSignature(List<int> bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < signature.length; i += 1) {
    if (bytes[i] != signature[i]) {
      return false;
    }
  }
  return true;
}

int _readBigEndianInt(List<int> bytes, int offset) {
  return bytes[offset] << 24 |
      bytes[offset + 1] << 16 |
      bytes[offset + 2] << 8 |
      bytes[offset + 3];
}
