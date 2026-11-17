import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../support/payment_migration_scenario.dart';
import '../support/movement_reference_repair_scenario.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('Migra v9 a pagos con categorías, conserva vínculos y revierte fallos sin perder historial', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_payments_',
    );
    final path = p.join(directory.path, 'payments.db');
    try {
      await verifyPaymentMigration(databaseFactoryFfi, path);
      await verifyMovementReferenceRepair(databaseFactoryFfi, path);
    } finally {
      await databaseFactoryFfi.deleteDatabase(path);
      await directory.delete();
    }
  });

  for (final version in [4, 9]) {
    test(
      'Migra v$version con renombrado antiguo y permite nuevos gastos y pagos',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'mi_quetzal_legacy_',
        );
        final path = p.join(directory.path, 'legacy.db');
        try {
          await verifyLegacyMovementUpgrade(databaseFactoryFfi, path, version);
        } finally {
          await databaseFactoryFfi.deleteDatabase(path);
          await directory.delete();
        }
      },
    );
  }

  test('El fallo de escritura conserva el formulario y ofrece un código sin exponer SQL ni datos', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_diagnostic_',
    );
    final path = p.join(directory.path, 'diagnostic.db');
    final local = LocalDatabase(factory: databaseFactoryFfi, path: path);
    final repo = SqliteMovementRepository(
      local,
      now: () => DateTime(2026, 11, 16),
    );
    final vm = MovementsViewModel(repo, now: () => DateTime(2026, 11, 16));
    try {
      final db = await local.database;
      await db.insert('accounts', {
        'id': 1,
        'name': 'Tarjeta sintética',
        'type': 'creditCard',
        'currency': 'gtq',
        'opening_minor': 10000,
        'opening_date': '2026-11-01',
      });
      await vm.load();
      await leaveTemporaryMovementReference(db);
      await db.execute('PRAGMA foreign_keys = ON');
      for (final type in [MovementType.expense, MovementType.creditPayment]) {
        expect(
          await vm.createMovement(
            type: type,
            accountId: 1,
            paymentFunding: type == MovementType.creditPayment
                ? PaymentFunding.externalCash
                : PaymentFunding.account,
            amount: '1.00',
            description: 'Texto sintético reservado',
            date: DateTime(2026, 11, 16),
          ),
          isFalse,
        );
        expect(vm.saveError, contains('BD-ESTRUCTURA'));
        expect(vm.saveError, isNot(contains('Texto sintético reservado')));
        expect(vm.saveError, isNot(contains('INSERT')));
        expect(vm.saveError, isNot(contains('movements_next')));
        expect(vm.isSaving, isFalse);
        expect(vm.movements, isEmpty);
      }
      expect(await db.query('movements'), isEmpty);
    } finally {
      vm.dispose();
      await local.close();
      await databaseFactoryFfi.deleteDatabase(path);
      await directory.delete();
    }
  });
}
