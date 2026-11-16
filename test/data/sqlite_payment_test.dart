import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/payment_migration_scenario.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('Migra v9 a pagos con categorías, conserva vínculos y revierte fallos sin perder historial', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_payments_',
    );
    final path = p.join(directory.path, 'payments.db');
    try {
      await verifyPaymentMigration(databaseFactoryFfi, path);
    } finally {
      await databaseFactoryFfi.deleteDatabase(path);
      await directory.delete();
    }
  });
}
