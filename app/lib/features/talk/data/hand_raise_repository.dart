import 'package:firebase_database/firebase_database.dart';

import '../../../core/firebase/app_database.dart';

class HandRaiseRepository {
  HandRaiseRepository({FirebaseDatabase? database})
    : _database = database ?? AppDatabase.instance();

  final FirebaseDatabase _database;

  DatabaseReference raisesRef(String groupId) {
    return _database.ref('handRaises/$groupId');
  }

  Future<void> setRaised({
    required String groupId,
    required String userId,
    required bool raised,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ref = _database.ref('handRaises/$groupId/$userId');
    if (raised) {
      await ref.set({
        'raised': true,
        'raisedAt': now,
        'updatedAt': now,
      });
    } else {
      await ref.remove();
    }
  }

  Future<void> clearRaised({
    required String groupId,
    required String userId,
  }) {
    return setRaised(groupId: groupId, userId: userId, raised: false);
  }

  static Map<String, bool> parseSnapshot(Object? value) {
    final result = <String, bool>{};
    if (value is! Map<Object?, Object?>) return result;

    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is Map<Object?, Object?>) {
        result[entry.key.toString()] = raw['raised'] == true;
      } else if (raw == true) {
        result[entry.key.toString()] = true;
      }
    }
    return result;
  }
}
