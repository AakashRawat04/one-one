import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../app/app_config.dart';

class AppDatabase {
  const AppDatabase._();

  static FirebaseDatabase instance() {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: AppConfig.firebaseDatabaseUrl,
    );
  }
}
