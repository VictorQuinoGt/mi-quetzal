import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/monthly_summary.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String path;
  late LocalDatabase database;
  late SqliteAccountRepository accounts;
  late SqliteMovementRepository movements;
  final today = DateTime(2026, 11, 2);
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_refund_test_',
    );
    path = p.join(directory.path, 'refund.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(database);
    movements = SqliteMovementRepository(database, now: () => today);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });
  Future<void> seed() async {
    await accounts.createAccount(
      AccountDetails(
        name: 'Banco sintético',
        type: AccountType.bank,
        openingBalance: Money(1000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await movements.createCategory(
      CategoryDetails(name: 'Gasto sintético', kind: CategoryKind.expense),
    );
    await movements.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: 1,
        amount: Money(500, Currency.gtq),
        categoryId: 1,
        date: DateTime(2026, 10, 31),
        description: "Compra ' sintética",
      ),
    );
  }

  MovementDetails refund(int cents, {int originalId = 1}) => MovementDetails(
    type: MovementType.refund,
    accountId: 1,
    originalMovementId: originalId,
    amount: Money(cents, Currency.gtq),
    date: today,
    description: "Devolución ' sintética",
  );
  Future<Database> oldDatabase() async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    await old.insert('accounts', {
      'id': 42,
      'name': 'Banco anterior sintético',
      'type': 'bank',
      'currency': 'gtq',
      'opening_minor': 1000,
      'opening_date': '2026-10-01',
    });
    await old.insert('debit_cards', {
      'id': 9,
      'name': 'Débito sintético',
      'account_id': 42,
    });
    await old.insert('categories', {
      'id': 3,
      'name': 'Gasto sintético',
      'kind': 'expense',
    });
    final row = {
      'type': 'expense',
      'account_id': 42,
      'debit_card_id': 9,
      'category_id': 3,
      'amount_minor': 500,
      'currency': 'gtq',
      'occurred_on': '2026-10-31',
      'description': 'Compra anterior sintética',
    };
    await old.insert('movements', {...row, 'id': 7});
    await old.insert('movements', {...row, 'id': 99});
    await old.delete('movements', where: 'id = ?', whereArgs: [99]);
    return old;
  }

  test('Migra v4 con todos los vínculos, restricciones e identidad autoincremental', () async {
    final old = await oldDatabase();
    final original = (await old.query('movements')).single;
    await old.close();
    final snapshot = await movements.getSnapshot();
    expect(snapshot.accounts.single.currentBalance.minorUnits, 500);
    expect(snapshot.movements.single.id, 7);
    final db = await database.database;
    final migrated = (await db.query('movements')).single;
    for (final field in original.keys) {
      expect(migrated[field], original[field], reason: field);
    }
    expect(migrated['original_movement_id'], isNull);
    expect(await db.getVersion(), LocalDatabase.schemaVersion);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    final after = await movements.createMovement(
      MovementDetails(
        type: MovementType.refund,
        accountId: 42,
        originalMovementId: 7,
        amount: Money(100, Currency.gtq),
        date: today,
        description: 'Devolución sintética',
      ),
    );
    expect(after.movements.first.id, greaterThan(99));
    expect(after.accounts.single.currentBalance.minorUnits, 600);
    await expectLater(
      db.update(
        'categories',
        {'kind': 'income'},
        where: 'id = ?',
        whereArgs: [3],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.update(
        'debit_cards',
        {'account_id': 99},
        where: 'id = ?',
        whereArgs: [9],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.update(
        'movements',
        {'category_id': 3},
        where: 'type = ?',
        whereArgs: ['refund'],
      ),
      throwsA(isA<DatabaseException>()),
    );
  });
  test('Fallo tardío de migración revierte tabla, disparadores, versión y datos', () async {
    final old = await oldDatabase();
    await old.execute(
      'CREATE TRIGGER movements_refund_insert BEFORE INSERT ON accounts BEGIN SELECT 1; END',
    );
    await old.close();
    await expectLater(
      movements.getSnapshot(),
      throwsA(isA<DatabaseException>()),
    );
    final preserved = await databaseFactoryFfi.openDatabase(path);
    expect(await preserved.getVersion(), 4);
    expect((await preserved.query('movements')).single['id'], 7);
    expect(
      await preserved.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'movements_with_refunds'",
      ),
      isEmpty,
    );
    expect(
      (await preserved.rawQuery(
        "SELECT seq FROM sqlite_sequence WHERE name = 'movements'",
      )).single['seq'],
      99,
    );
    expect(
      await preserved.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'movements_category_insert'",
      ),
      hasLength(1),
    );
    await preserved.close();
  });
  test('Devoluciones parciales persisten y recategorizar la compra actualiza su resumen', () async {
    await seed();
    await movements.createMovement(refund(125));
    await movements.createMovement(refund(375));
    await database.close();
    final snapshot = await movements.getSnapshot();
    expect(snapshot.accounts.single.currentBalance.minorUnits, 1000);
    expect(
      snapshot.movements
          .where((m) => m.details.isRefund)
          .map((m) => m.details.originalMovementId),
      [1, 1],
    );
    expect(snapshot.movements.last.details.description, "Compra ' sintética");
    await movements.createCategory(
      CategoryDetails(name: 'Otra sintética', kind: CategoryKind.expense),
    );
    final updated = await movements.assignCategory(1, 2);
    final report = MonthlySummary.calculate(
      updated,
      2026,
      11,
    ).currencies.single;
    expect(report.income.minorUnits, 0);
    expect(report.expense.minorUnits, -500);
    expect(report.expenseByCategory.single.categoryId, 2);
    expect(updated.accounts.single.currentBalance.minorUnits, 1000);
  });
  test(
    'Exceso y vínculo inválido no escriben filas ni cambian saldo',
    () async {
      await seed();
      await movements.createMovement(refund(400));
      for (final data in [
        refund(101),
        refund(1, originalId: 999),
        refund(1, originalId: 2),
      ]) {
        await expectLater(
          movements.createMovement(data),
          throwsA(isA<MovementValidationException>()),
        );
      }
      final snapshot = await movements.getSnapshot();
      expect(snapshot.movements, hasLength(2));
      expect(snapshot.accounts.single.currentBalance.minorUnits, 900);
    },
  );
  test('Devoluciones concurrentes no superan el importe original', () async {
    await seed();
    Future<bool> attempt() async {
      try {
        await movements.createMovement(refund(400));
        return true;
      } on MovementValidationException {
        return false;
      }
    }

    final results = await Future.wait([attempt(), attempt()]);
    expect(results.where((ok) => ok), hasLength(1));
    expect(
      (await movements.getSnapshot()).accounts.single.currentBalance.minorUnits,
      900,
    );
  });
  test('Fallo al reconstruir saldo revierte la devolución insertada', () async {
    await accounts.createAccount(
      AccountDetails(
        name: 'Rango sintético',
        type: AccountType.bank,
        openingBalance: Money(9007199254740991, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    for (final type in [MovementType.expense, MovementType.income]) {
      await movements.createMovement(
        MovementDetails(
          type: type,
          accountId: 1,
          amount: Money(500, Currency.gtq),
          date: today,
          description: 'Rango sintético',
        ),
      );
    }
    await expectLater(
      movements.createMovement(refund(1)),
      throwsA(isA<MovementValidationException>()),
    );
    expect((await movements.getSnapshot()).movements, hasLength(2));
    expect((await (await database.database).query('movements')), hasLength(2));
  });
  test('SQL protege límite, referencias, fechas y compra usada, sin bloquear categorías', () async {
    await seed();
    final db = await database.database;
    final row = {
      'type': 'refund',
      'account_id': 1,
      'original_movement_id': 1,
      'amount_minor': 400,
      'currency': 'gtq',
      'occurred_on': '2026-11-02',
      'description': 'Devolución sintética',
    };
    final id = await db.insert('movements', row);
    for (final changes in [
      <String, Object>{},
      {'original_movement_id': 999},
      {'original_movement_id': id},
      {'currency': 'usd'},
      {'occurred_on': '2026-10-30'},
      {'category_id': 1},
      {'amount_minor': 101},
    ]) {
      await expectLater(
        db.insert('movements', {...row, ...changes}),
        throwsA(isA<DatabaseException>()),
      );
    }
    await expectLater(
      db.update(
        'movements',
        {'amount_minor': 501},
        where: 'id = ?',
        whereArgs: [id],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.update(
        'movements',
        {'amount_minor': 1000},
        where: 'id = ?',
        whereArgs: [1],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.delete('movements', where: 'id = ?', whereArgs: [1]),
      throwsA(isA<DatabaseException>()),
    );
    await movements.assignCategory(1, null);
    expect(
      (await movements.getSnapshot()).accounts.single.currentBalance.minorUnits,
      900,
    );
  });
}
