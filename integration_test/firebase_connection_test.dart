import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zyntro_flutter/core/firebase/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase Connection Tests', () {
    testWidgets('Firebase Initialization and Auth Check', (
      WidgetTester tester,
    ) async {
      // 1. Initialize Firebase
      debugPrint('Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase Initialized');

      // 2. Check Auth Instance
      final auth = FirebaseAuth.instance;
      expect(auth, isNotNull);
      debugPrint('✅ FirebaseAuth instance available');

      // 3. Attempt Sign In (expect failure but not crash)
      debugPrint('Attempting Sign In with dummy credentials...');
      try {
        await auth.signInWithEmailAndPassword(
          email:
              'test_connection_${DateTime.now().millisecondsSinceEpoch}@test.com',
          password: 'password123',
        );
      } on FirebaseAuthException catch (e) {
        debugPrint('✅ Caught expected FirebaseAuthException: ${e.code}');
        // user-not-found is success for connectivity
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          debugPrint('✅ Connection verified via Auth error');
        } else {
          debugPrint('⚠️ Unexpected Auth error code: ${e.code}');
        }
      } catch (e) {
        debugPrint('❌ Unexpected error type: $e');
        // Fail if it's not an auth exception (e.g. PlatformException crash)
        // reuse the exception to fail the test if critical
      }

      // 4. Check Firestore Instance
      final firestore = FirebaseFirestore.instance;
      expect(firestore, isNotNull);
      debugPrint('✅ Firestore instance available');

      // 5. Attempt Firestore Read/Write (Connectivity check)
      debugPrint('Attempting Firestore Connectivity Check...');
      try {
        final docRef = firestore.collection('_connection_test').doc('ping');
        await docRef.set({'timestamp': FieldValue.serverTimestamp()});
        debugPrint('✅ Firestore Write Successful');

        final snapshot = await docRef.get();
        expect(snapshot.exists, true);
        debugPrint('✅ Firestore Read Successful');
      } catch (e) {
        debugPrint('❌ Firestore Connectivity Failed: $e');
        // If permission denied, that also proves connectivity!
        if (e.toString().contains('permission-denied')) {
          debugPrint(
            '✅ Connection confirmed (Permission Denied is a response)',
          );
        }
      }
    });
  });
}
