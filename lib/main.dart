import 'package:flutter/material.dart';

import 'app/mi_quetzal_app.dart';
import 'data/repositories/sqlite_account_repository.dart';
import 'data/repositories/sqlite_movement_repository.dart';
import 'data/services/local_database.dart';
import 'data/services/platform_database_factory.dart';
import 'data/repositories/sqlite_installment_repository.dart';
import 'data/services/installment_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = LocalDatabase(factory: platformDatabaseFactory);
  // La recuperación al abrir funciona aunque Android difiera o restrinja el trabajo de fondo.
  try {
    await startInstallmentBackgroundWork();
  } catch (_) {
    /* Se reintenta al próximo arranque. */
  }
  runApp(
    MiQuetzalApp(
      accountRepository: SqliteAccountRepository(database),
      movementRepository: SqliteMovementRepository(database),
      installmentRepository: SqliteInstallmentRepository(database),
      enableInstallmentPolling: true,
    ),
  );
}
