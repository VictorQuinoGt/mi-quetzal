import 'package:flutter/material.dart';

import 'app/mi_quetzal_app.dart';
import 'data/repositories/sqlite_account_repository.dart';
import 'data/repositories/sqlite_movement_repository.dart';
import 'data/services/local_database.dart';
import 'data/services/platform_database_factory.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = LocalDatabase(factory: platformDatabaseFactory);
  runApp(
    MiQuetzalApp(
      accountRepository: SqliteAccountRepository(database),
      movementRepository: SqliteMovementRepository(database),
    ),
  );
}
