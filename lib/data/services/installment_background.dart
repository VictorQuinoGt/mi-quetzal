import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../repositories/sqlite_installment_repository.dart';
import 'local_database.dart';
import 'platform_database_factory.dart';

@pragma('vm:entry-point')
void installmentBackgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    // Cada motor Flutter conserva su conexión; cerrar el worker no cierra la UI.
    final database = LocalDatabase(
      factory: platformDatabaseFactory,
      singleInstance: false,
    );
    try {
      await SqliteInstallmentRepository(database).generateDue();
      return true;
    } catch (_) {
      return false;
    } finally {
      await database.close();
    }
  });
}

Future<void> startInstallmentBackgroundWork() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await Workmanager().initialize(installmentBackgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    'mi_quetzal_installments',
    'installment_due_check',
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
