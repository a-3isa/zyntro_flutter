import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('storage rules contracts', () {
    late String rules;
    late String firebaseConfig;

    setUpAll(() {
      rules = File('firebase/storage.rules').readAsStringSync();
      firebaseConfig = File('firebase.json').readAsStringSync();
    });

    test('firebase deploy config includes storage rules', () {
      expect(firebaseConfig, contains('"storage"'));
      expect(firebaseConfig, contains('"rules":"firebase/storage.rules"'));
    });

    test('denies unknown storage paths by default', () {
      expect(rules, contains('match /{allPaths=**}'));
      expect(rules, contains('allow read, write: if false;'));
    });

    test('allows authenticated post media with bounded image metadata', () {
      expect(rules, contains('match /posts/{postId}/{fileName}'));
      expect(rules, contains('isImageContent()'));
      expect(rules, contains('isUnder5Mb()'));
      expect(rules, contains('isPostMediaReadable(postId)'));
      expect(rules, contains('function isPostMediaReadableData'));
      expect(rules, contains('allow read: if isPostMediaReadable(postId);'));
      expect(rules, contains('isPostOwner(postId)'));
      expect(rules, contains('allow write: if isPostOwner(postId) && isImageContent() && isUnder5Mb();'));
    });

    test('scopes profile photo writes to the owning user', () {
      expect(rules, contains('match /profilePhotos/{userId}/{fileName}'));
      expect(rules, contains('allow write: if isOwner(userId) && isImageContent() && isUnder5Mb();'));
    });

    test('allows session voice notes only for session participants', () {
      expect(rules, contains('match /voiceNotes/{sessionId}/{fileName}'));
      expect(rules, contains('isSessionParticipant(sessionId)'));
      expect(rules, contains('isAudioContent()'));
      expect(rules, contains('allow write: if isSessionParticipant(sessionId) && isAudioContent() && isUnder5Mb();'));
    });
  });
}
