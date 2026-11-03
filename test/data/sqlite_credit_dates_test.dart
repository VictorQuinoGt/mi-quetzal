import '../support/migration_expectations.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String path;
  late LocalDatabase database;
  late SqliteAccountRepository accounts;
  late SqliteMovementRepository movements;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_credit_dates_',
    );
    path = p.join(directory.path, 'dates.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(
      database,
      now: () => DateTime(2026, 11, 2),
    );
    movements = SqliteMovementRepository(database);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });
  Future<Database> legacy() async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    await old.insert('accounts', {
      'id': 7,
      'name': 'Crédito sintético',
      'type': 'creditCard',
      'currency': 'gtq',
      'opening_minor': 1000,
      'secondary_opening_minor': 2000,
      'credit_limit_minor': 5000,
      'last_four': '0042',
      'opening_date': '2026-10-01',
    });
    await old.insert('movements', {
      'id': 42,
      'type': 'expense',
      'account_id': 7,
      'amount_minor': 125,
      'currency': 'usd',
      'occurred_on': '2026-11-01',
      'description': 'Compra USD sintética',
    });
    return old;
  }

  AccountDetails credit({DateTime? closing, DateTime? payment}) =>
      AccountDetails(
        name: 'Crédito actualizado',
        type: AccountType.creditCard,
        openingBalance: Money(1000, Currency.gtq),
        secondaryOpeningBalance: Money(2000, Currency.usd),
        creditLimit: Money(5000, Currency.gtq),
        lastFour: '0042',
        openingDate: DateTime(2026, 10, 1),
        nextClosingDate: closing,
        nextPaymentDueDate: payment,
      );
  test('Migra v7 con fechas nulas, conservando aperturas, límites, ids y movimientos', () async {
    final old = await legacy();
    final rows = await old.query('movements');
    await old.close();
    final snapshot = await movements.getSnapshot();
    expect(snapshot.accounts.single.id, 7);
    expect(snapshot.accounts.single.details.nextClosingDate, isNull);
    expect(snapshot.accounts.single.details.nextPaymentDueDate, isNull);
    expect(snapshot.accounts.single.secondaryCurrentBalance!.minorUnits, 2125);
    expect(snapshot.accounts.single.details.creditLimit!.minorUnits, 5000);
    expectPreservedRows(
      await (await database.database).query('movements'),
      rows,
    );
  });
  test('Fechas completas independientes persisten y se pueden quitar sin efectos financieros', () async {
    final old = await legacy();
    await old.close();
    await movements.getSnapshot();
    final rows = await (await database.database).query('movements');
    await accounts.updateAccount(
      7,
      credit(closing: DateTime(2026, 11, 20), payment: DateTime(2026, 11, 5)),
    );
    await database.close();
    final account = (await accounts.getAccounts()).single;
    expect(account.details.nextClosingDate, DateTime(2026, 11, 20));
    expect(account.details.nextPaymentDueDate, DateTime(2026, 11, 5));
    expect(account.currentBalance.minorUnits, 1000);
    expect(account.secondaryCurrentBalance!.minorUnits, 2125);
    expectPreservedRows(
      await (await database.database).query('movements'),
      rows,
    );
    await accounts.updateAccount(7, credit());
    expect(
      (await accounts.getAccounts()).single.details.nextClosingDate,
      isNull,
    );
  });
  test(
    'Fallo tardío de migración revierte columnas y conserva versión v7',
    () async {
      final old = await legacy();
      await old.execute(
        'ALTER TABLE accounts ADD COLUMN next_payment_due_date TEXT',
      );
      await old.close();
      await expectLater(
        movements.getSnapshot(),
        throwsA(isA<DatabaseException>()),
      );
      final preserved = await databaseFactoryFfi.openDatabase(path);
      expect(await preserved.getVersion(), 7);
      expect(
        (await preserved.rawQuery('PRAGMA table_info(accounts)'))
            .where((row) => row['name'] == 'next_closing_date'),
        isEmpty,
      );
      expect((await preserved.query('accounts')).single['opening_minor'], 1000);
      expect((await preserved.query('movements')).single['id'], 42);
      await preserved.close();
    },
  );
}
