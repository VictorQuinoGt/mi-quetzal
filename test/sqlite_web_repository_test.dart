import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'domain/money_test.dart' as money_tests;
import 'domain/movement_rules_test.dart' as movement_rules_tests;

void main() {
  // En Flutter 3.47/Windows, el ejecutor web pierde separadores en rutas anidadas.
  // Este archivo raíz agrupa también las comprobaciones de precisión en JavaScript.
  if (kIsWeb) {
    money_tests.main();
    movement_rules_tests.main();
  }
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
      expect(await (await database.database).getVersion(), 2);
    },
    skip: !kIsWeb,
  );
}
