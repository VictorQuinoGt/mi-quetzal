import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/monthly_summary.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'domain/money_test.dart' as money_tests;
import 'domain/movement_rules_test.dart' as movement_rules_tests;
import 'domain/debit_card_test.dart' as debit_card_tests;
import 'domain/movement_filter_test.dart' as movement_filter_tests;
import 'domain/categories_and_summary_test.dart' as categories_summary_tests;
import 'domain/refund_test.dart' as refund_tests;

void main() {
  // En Flutter 3.47/Windows, el ejecutor web pierde separadores en rutas anidadas.
  // Este archivo raíz agrupa también las comprobaciones de precisión en JavaScript.
  if (kIsWeb) {
    money_tests.main();
    movement_rules_tests.main();
    debit_card_tests.main();
    movement_filter_tests.main();
    categories_summary_tests.main();
    refund_tests.main();
  }
  test('SQLite web migra v4 y persiste devoluciones con saldo a favor sin ingresos', () async {
    final factory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
        sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
        indexedDbName: 'mi_quetzal_browser_tests',
      ),
    );
    final path = 'test_refunds_${DateTime.now().microsecondsSinceEpoch}.db';
    final database = LocalDatabase(factory: factory, path: path);
    addTearDown(() async {
      await database.close();
      await factory.deleteDatabase(path);
    });
    final old = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    for (final entry in [(1, 'bank', 10000), (2, 'creditCard', 0)]) {
      await old.insert('accounts', {
        'id': entry.$1,
        'name': 'Cuenta sintética',
        'type': entry.$2,
        'currency': 'gtq',
        'opening_minor': entry.$3,
        'opening_date': '2026-10-01',
      });
    }
    await old.insert('debit_cards', {
      'id': 9,
      'name': 'Débito sintético',
      'account_id': 1,
    });
    await old.insert('categories', {
      'id': 3,
      'name': 'Gasto sintético',
      'kind': 'expense',
    });
    for (final entry in [(7, 1, 125, 9), (8, 2, 500, null)]) {
      await old.insert('movements', {
        'id': entry.$1,
        'type': 'expense',
        'account_id': entry.$2,
        'amount_minor': entry.$3,
        'debit_card_id': entry.$4,
        'category_id': 3,
        'currency': 'gtq',
        'occurred_on': '2026-10-31',
        'description': 'Compra sintética',
      });
    }
    await old.close();
    final repository = SqliteMovementRepository(
      database,
      now: () => DateTime(2026, 11, 2),
    );
    final migrated = await repository.getSnapshot();
    expect(
      migrated.movements.singleWhere((m) => m.id == 7).details.debitCardId,
      9,
    );
    await repository.createMovement(
      MovementDetails(
        type: MovementType.creditPayment,
        accountId: 1,
        counterpartyAccountId: 2,
        amount: Money(500, Currency.gtq),
        date: DateTime(2026, 11, 1),
        description: 'Pago sintético',
      ),
    );
    MovementDetails refund(int original, int account, int cents) =>
        MovementDetails(
          type: MovementType.refund,
          accountId: account,
          originalMovementId: original,
          amount: Money(cents, Currency.gtq),
          date: DateTime(2026, 11, 2),
          description: 'Devolución sintética',
        );
    await repository.createMovement(refund(7, 1, 25));
    await repository.createMovement(refund(7, 1, 100));
    await repository.createMovement(refund(8, 2, 500));
    await expectLater(
      repository.createMovement(refund(7, 1, 1)),
      throwsA(isA<MovementValidationException>()),
    );
    await database.close();
    final snapshot = await repository.getSnapshot();
    expect(snapshot.accounts.map((a) => a.currentBalance.minorUnits), [
      9500,
      -500,
    ]);
    expect(snapshot.movements, hasLength(6));
    final report = MonthlySummary.calculate(
      snapshot,
      2026,
      11,
    ).currencies.single;
    expect(report.income.minorUnits, 0);
    expect(report.expense.minorUnits, -625);
    expect(report.expenseByCategory.single.categoryId, 3);
    expect(
      await (await database.database).rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
  }, skip: !kIsWeb);
  test('SQLite web conserva monedas e importes al cerrar y abrir', () async {
    final factory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
        sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
        indexedDbName: 'mi_quetzal_browser_tests',
      ),
    );
    final path = 'test_accounts_${DateTime.now().microsecondsSinceEpoch}.db';
    final database = LocalDatabase(factory: factory, path: path);
    addTearDown(() async {
      await database.close();
      await factory.deleteDatabase(path);
    });
    final repository = SqliteAccountRepository(database);
    for (final currency in Currency.values) {
      await repository.createAccount(
        AccountDetails(
          name: 'Cuenta sintética',
          type: AccountType.bank,
          openingBalance: Money.parse('0.29', currency),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    await database.close();
    final accounts = await repository.getAccounts();
    expect(accounts.map((a) => a.details.openingBalance), [
      Money(29, Currency.gtq),
      Money(29, Currency.usd),
    ]);
  }, skip: !kIsWeb);

  test(
    'SQLite web migra desde v1 y conserva compra y pago vinculados al reabrir',
    () async {
      final factory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(
          sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
          sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
          indexedDbName: 'mi_quetzal_browser_tests',
        ),
      );
      final path = 'test_migration_${DateTime.now().microsecondsSinceEpoch}.db';
      final database = LocalDatabase(factory: factory, path: path);
      addTearDown(() async {
        await database.close();
        await factory.deleteDatabase(path);
      });
      final old = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
        ),
      );
      for (final entry in [(1, 'bank', 10000), (2, 'creditCard', 0)]) {
        await old.insert('accounts', {
          'id': entry.$1,
          'name': 'Cuenta sintética',
          'type': entry.$2,
          'currency': 'gtq',
          'opening_minor': entry.$3,
          'opening_date': '2026-10-01',
        });
      }
      await old.close();
      final repository = SqliteMovementRepository(
        database,
        now: () => DateTime(2026, 11, 2),
      );
      await repository.createMovement(
        MovementDetails(
          type: MovementType.expense,
          accountId: 2,
          amount: Money(5000, Currency.gtq),
          date: DateTime(2026, 11, 2),
          description: 'Compra sintética',
        ),
      );
      await repository.createMovement(
        MovementDetails(
          type: MovementType.creditPayment,
          accountId: 1,
          counterpartyAccountId: 2,
          amount: Money(2000, Currency.gtq),
          date: DateTime(2026, 11, 2),
          description: 'Pago sintético',
        ),
      );
      await database.close();
      final snapshot = await repository.getSnapshot();
      expect(snapshot.accounts.map((a) => a.currentBalance.minorUnits), [
        8000,
        3000,
      ]);
      expect(snapshot.movements, hasLength(2));
      expect(
        snapshot.movements.where((m) => m.details.isExpense),
        hasLength(1),
      );
      expect(
        await (await database.database).getVersion(),
        LocalDatabase.schemaVersion,
      );
    },
    skip: !kIsWeb,
  );
  test(
    'SQLite web migra desde v2 y conserva compras de dos tarjetas de un banco',
    () async {
      final factory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(
          sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
          sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
          indexedDbName: 'mi_quetzal_browser_tests',
        ),
      );
      final path = 'test_debit_${DateTime.now().microsecondsSinceEpoch}.db';
      final database = LocalDatabase(factory: factory, path: path);
      addTearDown(() async {
        await database.close();
        await factory.deleteDatabase(path);
      });
      final old = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
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
      await old.insert('movements', {
        'id': 7,
        'type': 'expense',
        'account_id': 42,
        'amount_minor': 100,
        'currency': 'gtq',
        'occurred_on': '2026-11-01',
        'description': 'Compra anterior sintética',
      });
      await old.close();
      final accounts = SqliteAccountRepository(database);
      final movements = SqliteMovementRepository(
        database,
        now: () => DateTime(2026, 11, 2),
      );
      final before = await movements.getSnapshot();
      expect(before.movements.single.details.debitCardId, isNull);
      expect(before.accounts.single.currentBalance.minorUnits, 900);
      final first = await accounts.createDebitCard(
        DebitCardDetails(
          name: 'Débito sintético',
          accountId: 42,
          lastFour: '0042',
        ),
      );
      final second = await accounts.createDebitCard(
        DebitCardDetails(name: 'Otro débito sintético', accountId: 42),
      );
      for (final card in [first, second]) {
        await movements.createMovement(
          MovementDetails(
            type: MovementType.expense,
            accountId: 42,
            debitCardId: card.id,
            amount: Money(100, Currency.gtq),
            date: DateTime(2026, 11, 2),
            description: 'Compra con débito sintética',
          ),
        );
      }
      final db = await database.database;
      await expectLater(
        db.insert('movements', {
          'type': 'income',
          'account_id': 42,
          'debit_card_id': first.id,
          'amount_minor': 100,
          'currency': 'gtq',
          'occurred_on': '2026-11-02',
          'description': 'Prueba inválida sintética',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await database.close();
      final after = await movements.getSnapshot();
      expect(after.accounts, hasLength(1));
      expect(after.accounts.single.currentBalance.minorUnits, 700);
      expect(after.debitCards, hasLength(2));
      expect(after.movements.map((m) => m.details.debitCardId), [
        second.id,
        first.id,
        null,
      ]);
      expect(
        await (await database.database).getVersion(),
        LocalDatabase.schemaVersion,
      );
    },
    skip: !kIsWeb,
  );
  test(
    'SQLite web migra desde v3, categoriza y conserva resumen sin doble gasto',
    () async {
      final factory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(
          sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
          sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
          indexedDbName: 'mi_quetzal_browser_tests',
        ),
      );
      final path =
          'test_categories_${DateTime.now().microsecondsSinceEpoch}.db';
      final database = LocalDatabase(factory: factory, path: path);
      addTearDown(() async {
        await database.close();
        await factory.deleteDatabase(path);
      });
      final old = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
        ),
      );
      for (final entry in [(42, 'bank', 10000), (43, 'creditCard', 0)]) {
        await old.insert('accounts', {
          'id': entry.$1,
          'name': 'Cuenta anterior sintética',
          'type': entry.$2,
          'currency': 'gtq',
          'opening_minor': entry.$3,
          'opening_date': '2026-10-01',
        });
      }
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
        'amount_minor': 125,
        'currency': 'gtq',
        'occurred_on': '2026-11-01',
        'description': 'Compra anterior sintética',
      });
      await old.close();
      final repository = SqliteMovementRepository(
        database,
        now: () => DateTime(2026, 11, 2),
      );
      final migrated = await repository.getSnapshot();
      expect(migrated.categories, isEmpty);
      expect(migrated.movements.single.details.categoryId, isNull);
      final expenseCategory = (await repository.createCategory(
        CategoryDetails(name: 'Gasto sintético', kind: CategoryKind.expense),
      )).categories.last.id;
      final incomeCategory = (await repository.createCategory(
        CategoryDetails(name: 'Ingreso sintético', kind: CategoryKind.income),
      )).categories.last.id;
      await repository.assignCategory(7, expenseCategory);
      for (final entry in [
        (MovementType.expense, 43, null, 500, expenseCategory),
        (MovementType.creditPayment, 42, 43, 200, null),
        (MovementType.income, 42, null, 1000, incomeCategory),
      ]) {
        await repository.createMovement(
          MovementDetails(
            type: entry.$1,
            accountId: entry.$2,
            counterpartyAccountId: entry.$3,
            amount: Money(entry.$4, Currency.gtq),
            categoryId: entry.$5,
            date: DateTime(2026, 11, 2),
            description: 'Operación sintética',
          ),
        );
      }
      await database.close();
      final after = await repository.getSnapshot();
      expect(after.accounts.map((a) => a.currentBalance.minorUnits), [
        10675,
        300,
      ]);
      expect(after.movements, hasLength(4));
      final summary = MonthlySummary.calculate(
        after,
        2026,
        11,
      ).currencies.single;
      expect(summary.income.minorUnits, 1000);
      expect(summary.expense.minorUnits, 625);
      expect(summary.difference.minorUnits, 375);
      expect(summary.expenseByCategory.single.categoryId, expenseCategory);
      final previous = after.movements.singleWhere((m) => m.id == 7);
      expect(previous.details.description, 'Compra anterior sintética');
      expect(previous.details.debitCardId, 9);
      expect(
        await (await database.database).getVersion(),
        LocalDatabase.schemaVersion,
      );
    },
    skip: !kIsWeb,
  );
}
