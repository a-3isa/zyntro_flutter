import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../features/auth/auth_providers.dart';

/// Builds a portable JSON export of the signed-in user's data (Z-PRV-002).
class DataExportService {
  DataExportService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Writes a JSON file under the app documents directory and returns its path.
  Future<File> exportUserData(String userId) async {
    final profileSnap = await _firestore.collection('users').doc(userId).get();
    final workoutsSnap = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();
    final postsSnap = await _firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .limit(200)
        .get();

    final payload = <String, dynamic>{
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'userId': userId,
      'profile': profileSnap.data() ?? <String, dynamic>{},
      'workouts': workoutsSnap.docs
          .map((d) => {'id': d.id, ..._sanitize(d.data())})
          .toList(),
      'posts': postsSnap.docs
          .map((d) => {'id': d.id, ..._sanitize(d.data())})
          .toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/zyntro-export-$userId-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    debugPrint('[DataExport] Wrote ${file.path}');
    return file;
  }

  Map<String, dynamic> _sanitize(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value is Timestamp) {
        out[key] = value.toDate().toUtc().toIso8601String();
      } else if (value is Map) {
        out[key] = _sanitize(Map<String, dynamic>.from(value));
      } else if (value is List) {
        out[key] = value.map((item) {
          if (item is Timestamp) {
            return item.toDate().toUtc().toIso8601String();
          }
          if (item is Map) {
            return _sanitize(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        out[key] = value;
      }
    });
    return out;
  }
}

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService(ref.watch(authFirestoreProvider));
});
