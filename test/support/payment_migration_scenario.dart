import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/monthly_summary.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'migration_expectations.dart';

/// Escenario compartido por SQLite nativo y SQLite/IndexedDB del navegador.
Future<void> verifyPaymentMigration(
  DatabaseFactory factory,
  String path,
) async {
  final old = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 9,
      onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
    ),
  );
  for (final entry in [(1, 'creditCard'), (2, 'bank')]) {
    await old.insert('accounts', {
      'id': entry.$1,
      'name': 'Cuenta sintética ${entry.$1}',
      'type': entry.$2,
      'currency': 'gtq',
      'opening_minor': 10000,
      'opening_date': '2026-10-01',
      if (entry.$1 == 1) 'secondary_opening_minor': 3000,
    });
  }
  await old.insert('debit_cards', {
    'id': 7,
    'name': 'Débito sintético',
    'account_id': 2,
  });
  await old.insert('categories', {
    'id': 1,
    'name': 'Gasto sintético',
    'kind': 'expense',
  });
  await old.insert('categories', {
    'id': 2,
    'name': 'Ingreso sintético',
    'kind': 'income',
  });
  Map<String, Object?> row(
    int id, {
    String type = 'expense',
    int account = 1,
    int amount = 100,
    int? category,
    int? original,
    int? other,
  }) => {
    'id': id,
    'type': type,
    'account_id': account,
    'amount_minor': amount,
    'currency': 'gtq',
    'occurred_on': '2026-11-01',
    'description': 'Movimiento sintético $id',
    'category_id': category,
    'original_movement_id': original,
    'counterparty_account_id': other,
  };
  await old.insert('movements', {
    ...row(10, account: 2, category: 1),
    'debit_card_id': 7,
  });
  await old.insert('movements', row(11, amount: 300, category: 1));
  await old.insert(
    'movements',
    row(12, type: 'refund', account: 2, amount: 20, original: 10),
  );
  await old.insert(
    'movements',
    row(13, type: 'creditPayment', account: 2, other: 1),
  );
  await old.insert('installment_plans', {
    'id': 5,
    'description': 'Plan sintético',
    'original_description': 'Movimiento sintético 11',
    'account_id': 1,
    'category_id': 1,
    'currency': 'gtq',
    'original_minor': 300,
    'count': 3,
    'monthly_minor': 100,
    'first_date': '2026-11-01',
    'charge_day': 1,
    'previous_count': 0,
    'reference_date': '2026-11-01',
    'cost_mode': 'noInterest',
    'limit_mode': 'ordinary',
    'original_movement_id': 11,
  });
  await old.insert('movements', {
    ...row(14, category: 1),
    'origin': 'installmentCharge',
    'installment_plan_id': 5,
    'installment_number': 1,
    'recognized_expense_minor': 0,
  });
  await old.insert('movements', {
    ...row(15, amount: 300, category: 1),
    'origin': 'installmentConversion',
    'installment_plan_id': 5,
    'installment_number': 0,
    'recognized_expense_minor': 0,
  });
  await old.insert('movements', row(16, category: 1));
  for (var number = 1; number <= 3; number++) {
    await old.insert('installments', {
      'plan_id': 5,
      'number': number,
      'due_date': '2026-${number == 1 ? '11-01' : '12-0$number'}',
      'amount_minor': 100,
      'previously_loaded': 0,
      'movement_id': number == 1 ? 14 : null,
    });
  }
  await old.insert('installment_reconciliations', {
    'source_movement_id': 16,
    'target_movement_id': 14,
    'reference': 'Referencia sintética',
  });
  await old.insert('installment_revisions', {
    'plan_id': 5,
    'recorded_on': '2026-11-01',
    'note': 'Nota sintética',
  });
  await old.insert('movements', row(999));
  await old.delete('movements', where: 'id = 999');
  await old.insert('categories', {
    'id': 888,
    'name': 'Temporal sintética',
    'kind': 'expense',
  });
  await old.delete('categories', where: 'id = 888');
  const tables = [
    'accounts',
    'debit_cards',
    'categories',
    'movements',
    'installment_plans',
    'installments',
    'installment_reconciliations',
    'installment_revisions',
    'sqlite_sequence',
  ];
  final before = <String, List<Map<String, Object?>>>{
    for (final table in tables) table: await old.query(table),
  };
  final schemaBefore = await old.rawQuery(
    'SELECT name,sql FROM sqlite_master ORDER BY name',
  );
  await old.close();

  // Un fallo incluso después de reconstruir ambas tablas revierte datos y DDL.
  await expectLater(
    factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 10,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = OFF'),
        onUpgrade: (db, from, to) async {
          await LocalDatabase.migrate(db, from, to);
          throw StateError('Fallo sintético después de migrar');
        },
      ),
    ),
    throwsA(anything),
  );
  final rollback = await factory.openDatabase(path);
  expect(await rollback.getVersion(), 9);
  for (final table in tables) {
    expect(await rollback.query(table), before[table], reason: table);
  }
  expect(
    await rollback.rawQuery('SELECT name,sql FROM sqlite_master ORDER BY name'),
    schemaBefore,
  );
  await rollback.close();

  var local = LocalDatabase(factory: factory, path: path);
  try {
    final db = await local.database;
    expect(await db.getVersion(), 10);
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    for (final table in tables.where((t) => t != 'sqlite_sequence')) {
      final actual = await db.query(table);
      if (table == 'installments' || table == 'installment_reconciliations') {
        expect(actual, before[table], reason: table);
      } else {
        expectPreservedRows(actual, before[table]!);
      }
    }
    expect(
      (await db.query('movements'))
          .every((m) => m['payment_funding'] == 'account'),
      isTrue,
    );
    var repository = SqliteMovementRepository(
      local,
      now: () => DateTime(2026, 11, 1),
    );
    final baseline = await repository.getSnapshot();
    final categorySnapshot = await repository.createCategory(
      CategoryDetails(name: 'Pago sintético', kind: CategoryKind.payment),
    );
    final category = categorySnapshot.categories.singleWhere(
      (c) => c.details.kind == CategoryKind.payment,
    );
    expect(category.id, greaterThan(888));
    await repository.assignCategory(13, category.id);
    final paid = await repository.createMovement(
      MovementDetails(
        type: MovementType.creditPayment,
        accountId: 1,
        paymentFunding: PaymentFunding.externalCash,
        amount: Money(250, Currency.usd),
        date: DateTime(2026, 11, 1),
        description: 'Pago en agencia sintético',
        categoryId: category.id,
      ),
    );
    final payment = paid.movements.singleWhere(
      (m) => m.details.isExternalCashPayment,
    );
    expect(payment.id, greaterThan(999));
    expect(paid.accounts.first.balanceFor(Currency.usd)!.minorUnits, 2750);
    expect(
      paid.accounts[1].currentBalance,
      baseline.accounts[1].currentBalance,
    );
    expect(
      MonthlySummary.calculate(paid, 2026, 11).currencies.first.expense,
      MonthlySummary.calculate(baseline, 2026, 11).currencies.first.expense,
    );
    await repository.assignCategory(payment.id, null);
    final reclassified = await repository.assignCategory(
      payment.id,
      category.id,
    );
    expect(
      reclassified.accounts.first.balanceFor(Currency.usd),
      paid.accounts.first.balanceFor(Currency.usd),
    );

    // Las restricciones siguen activas después de reemplazar ambas tablas.
    for (final change in [
      {'category_id': 1},
      {'account_id': 2},
      {'counterparty_account_id': 2},
      {'type': 'income'},
      {'debit_card_id': 7},
      {'payment_funding': 'unknown'},
    ]) {
      await expectLater(
        db.update(
          'movements',
          change,
          where: 'id = ?',
          whereArgs: [payment.id],
        ),
        throwsA(isA<DatabaseException>()),
      );
    }
    await expectLater(
      db.update(
        'categories',
        {'kind': 'income'},
        where: 'id = ?',
        whereArgs: [category.id],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.update('categories', {'kind': 'payment'}, where: 'id = 1'),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.delete('movements', where: 'id = 11'),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.delete('categories', where: 'id = ?', whereArgs: [category.id]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.update('installments', {
        'amount_minor': 200,
      }, where: 'plan_id = 5 AND number = 1'),
      throwsA(isA<DatabaseException>()),
    );
    await local.close();
    local = LocalDatabase(factory: factory, path: path);
    repository = SqliteMovementRepository(
      local,
      now: () => DateTime(2026, 11, 1),
    );
    final reopened = await repository.getSnapshot();
    final stored = reopened.movements
        .singleWhere((m) => m.id == payment.id)
        .details;
    expect(stored.paymentFunding, PaymentFunding.externalCash);
    expect(stored.categoryId, category.id);
    expect(stored.counterpartyAccountId, isNull);
    expect(reopened.accounts.first.balanceFor(Currency.usd)!.minorUnits, 2750);
    expect(
      await (await local.database).rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
  } finally {
    await local.close();
  }
}
