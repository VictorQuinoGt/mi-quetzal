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
  final date = DateTime(2026, 11, 2);
  Future<Account> bank() => accounts.createAccount(
    AccountDetails(
      name: 'Banco sintético',
      type: AccountType.bank,
      openingBalance: Money(10000, Currency.gtq),
      openingDate: DateTime(2026, 10, 1),
    ),
  );
  MovementDetails expense(int accountId, {int? categoryId}) => MovementDetails(
    type: MovementType.expense,
    accountId: accountId,
    amount: Money(125, Currency.gtq),
    date: date,
    description: "Compra ' original sintética",
    categoryId: categoryId,
  );
  Future<int> category(CategoryKind kind) async =>
      (await movements.createCategory(
        CategoryDetails(name: 'Categoría sintética', kind: kind),
      )).categories.last.id;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_categories_test_',
    );
    path = p.join(directory.path, 'categories.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(database);
    movements = SqliteMovementRepository(database, now: () => date);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });

  test(
    'Migra desde v3 conservando tarjeta y movimiento sin asignar categoría',
    () async {
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
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
        'name': 'Débito anterior sintético',
        'account_id': 42,
      });
      await old.insert('movements', {
        'id': 7,
        'type': 'expense',
        'account_id': 42,
        'debit_card_id': 9,
        'amount_minor': 100,
        'currency': 'gtq',
        'occurred_on': '2026-11-01',
        'description': 'Compra anterior sintética',
      });
      await old.close();
      final snapshot = await movements.getSnapshot();
      expect(snapshot.accounts.single.currentBalance.minorUnits, 900);
      expect(snapshot.movements.single.id, 7);
      expect(snapshot.movements.single.details.categoryId, isNull);
      expect(snapshot.movements.single.details.debitCardId, 9);
      expect(snapshot.categories, isEmpty);
      expect(
        await (await database.database).getVersion(),
        LocalDatabase.schemaVersion,
      );
    },
  );

  test(
    'Fallo al migrar no borra los datos de v3 ni altera su versión',
    () async {
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
        ),
      );
      await old.insert('accounts', {
        'name': 'Banco anterior sintético',
        'type': 'bank',
        'currency': 'gtq',
        'opening_minor': 1000,
        'opening_date': '2026-10-01',
      });
      await old.execute('CREATE TABLE categories (sentinel TEXT)');
      await old.close();
      await expectLater(
        movements.getSnapshot(),
        throwsA(isA<DatabaseException>()),
      );
      final preserved = await databaseFactoryFfi.openDatabase(path);
      expect(await preserved.getVersion(), 3);
      expect((await preserved.query('accounts')).single['opening_minor'], 1000);
      await preserved.close();
    },
  );

  test('Crear y reasignar categoría preserva identidad y todos los datos financieros', () async {
    final account = await bank();
    final before = await movements.createMovement(expense(account.id));
    final id = await category(CategoryKind.expense);
    final assigned = await movements.assignCategory(
      before.movements.single.id,
      id,
    );
    expect(assigned.movements.single.id, before.movements.single.id);
    expect(assigned.movements.single.details.categoryId, id);
    expect(
      assigned.movements.single.details.amount,
      before.movements.single.details.amount,
    );
    expect(
      assigned.movements.single.details.description,
      before.movements.single.details.description,
    );
    expect(assigned.movements.single.details.date, date);
    expect(
      assigned.accounts.single.currentBalance,
      before.accounts.single.currentBalance,
    );
    await database.close();
    final reopened = await movements.getSnapshot();
    expect(reopened.categories.single.id, id);
    expect(reopened.movements.single.details.categoryId, id);
    expect(
      MonthlySummary.calculate(
        reopened,
        2026,
        11,
      ).currencies.single.expenseByCategory.single.categoryId,
      id,
    );
    final unassigned = await movements.assignCategory(
      before.movements.single.id,
      null,
    );
    expect(unassigned.movements.single.details.categoryId, isNull);
    expect(unassigned.accounts.single.currentBalance.minorUnits, 9875);
  });

  test('Rechaza referencias incompatibles y no modifica movimientos', () async {
    final account = await bank();
    final expenseId = await category(CategoryKind.expense);
    final incomeId = await category(CategoryKind.income);
    final original = await movements.createMovement(
      expense(account.id, categoryId: expenseId),
    );
    for (final id in [incomeId, 999]) {
      await expectLater(
        movements.assignCategory(original.movements.single.id, id),
        throwsA(isA<MovementValidationException>()),
      );
    }
    await expectLater(
      movements.assignCategory(999, expenseId),
      throwsA(isA<MovementValidationException>()),
    );
    await expectLater(
      movements.createMovement(expense(account.id, categoryId: incomeId)),
      throwsA(isA<MovementValidationException>()),
    );
    expect(
      (await movements.getSnapshot()).movements.single.details.categoryId,
      expenseId,
    );
  });

  test(
    'Un fallo SQL revierte categorización y creación sin afectar saldos',
    () async {
      final account = await bank();
      final before = await movements.createMovement(expense(account.id));
      final id = await category(CategoryKind.expense);
      final db = await database.database;
      await db.execute(
        "CREATE TRIGGER reject_assignment BEFORE UPDATE ON movements BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END",
      );
      await expectLater(
        movements.assignCategory(before.movements.single.id, id),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        (await movements.getSnapshot()).movements.single.details.categoryId,
        isNull,
      );
      expect(
        (await accounts.getAccounts()).single.currentBalance.minorUnits,
        9875,
      );
      await db.execute(
        "CREATE TRIGGER reject_category AFTER INSERT ON categories BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END",
      );
      await expectLater(
        category(CategoryKind.expense),
        throwsA(isA<DatabaseException>()),
      );
      expect((await movements.getSnapshot()).categories, hasLength(1));
    },
  );

  test('SQL protege tipo, referencias y categorías usadas; alias idénticos mantienen identidades', () async {
    final account = await bank();
    final first = await category(CategoryKind.expense);
    final second = await category(CategoryKind.expense);
    expect(first, isNot(second));
    await movements.createMovement(expense(account.id, categoryId: first));
    final db = await database.database;
    await expectLater(
      db.update(
        'categories',
        {'kind': 'income'},
        where: 'id = ?',
        whereArgs: [first],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.delete('categories', where: 'id = ?', whereArgs: [first]),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert('movements', {
        'type': 'income',
        'account_id': account.id,
        'amount_minor': 100,
        'currency': 'gtq',
        'occurred_on': '2026-11-02',
        'description': 'Prueba sintética',
        'category_id': first,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
