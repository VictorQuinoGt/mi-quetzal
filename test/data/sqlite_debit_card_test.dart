import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/money.dart';
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
  Future<Account> account(
    AccountType type, {
    Currency currency = Currency.gtq,
  }) => accounts.createAccount(
    AccountDetails(
      name: 'Cuenta sintética',
      type: type,
      openingBalance: Money(1000, currency),
      openingDate: DateTime(2026, 10, 1),
    ),
  );
  MovementDetails purchase(
    int id,
    int cardId, {
    Currency currency = Currency.gtq,
  }) => MovementDetails(
    type: MovementType.expense,
    accountId: id,
    debitCardId: cardId,
    amount: Money(100, currency),
    date: today,
    description: 'Compra sintética',
  );
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mi_quetzal_debit_test_');
    path = p.join(directory.path, 'debit.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(database);
    movements = SqliteMovementRepository(database, now: () => today);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });

  test(
    'Migra esquema 2 conservando cuentas y movimientos con tarjeta nula',
    () async {
      final old = await databaseFactoryFfi.openDatabase(
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
      final snapshot = await movements.getSnapshot();
      expect(snapshot.accounts.single.id, 42);
      expect(snapshot.accounts.single.currentBalance.minorUnits, 900);
      expect(snapshot.movements.single.id, 7);
      expect(snapshot.movements.single.details.debitCardId, isNull);
      expect(snapshot.debitCards, isEmpty);
      expect(await (await database.database).getVersion(), 3);
    },
  );

  test('Fallo de migración conserva la versión 2 y todos sus datos', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
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
    await old.execute('CREATE TABLE debit_cards (sentinel TEXT)');
    await old.close();
    await expectLater(
      accounts.getAccounts(),
      throwsA(isA<DatabaseException>()),
    );
    final preserved = await databaseFactoryFfi.openDatabase(path);
    expect(await preserved.getVersion(), 2);
    expect((await preserved.query('accounts')).single['opening_minor'], 1000);
    await preserved.close();
  });

  test(
    'Persiste dos tarjetas de un banco y sus compras sin duplicar saldo',
    () async {
      final bank = await account(AccountType.bank);
      final first = await accounts.createDebitCard(
        DebitCardDetails(
          name: 'Débito sintético',
          accountId: bank.id,
          lastFour: '0042',
        ),
      );
      final second = await accounts.createDebitCard(
        DebitCardDetails(name: 'Débito sintético', accountId: bank.id),
      );
      await movements.createMovement(purchase(bank.id, first.id));
      await movements.createMovement(purchase(bank.id, second.id));
      await database.close();
      final snapshot = await movements.getSnapshot();
      expect(snapshot.accounts, hasLength(1));
      expect(snapshot.accounts.single.currentBalance.minorUnits, 800);
      expect(snapshot.debitCards.map((c) => c.id), [first.id, second.id]);
      expect(snapshot.debitCards.first.details.lastFour, '0042');
      expect(snapshot.movements.map((m) => m.details.debitCardId), [
        second.id,
        first.id,
      ]);
      expect(await accounts.getDebitCards(), hasLength(2));
    },
  );

  test(
    'Rechaza vinculación a efectivo, crédito o cuenta inexistente',
    () async {
      final cash = await account(AccountType.cash);
      final credit = await account(AccountType.creditCard);
      for (final id in [cash.id, credit.id, 999]) {
        await expectLater(
          accounts.createDebitCard(
            DebitCardDetails(name: 'Débito sintético', accountId: id),
          ),
          throwsA(isA<DebitCardValidationException>()),
        );
      }
      expect(await accounts.getDebitCards(), isEmpty);
    },
  );

  test('Compra con otra cuenta o moneda no escribe ni cambia saldos', () async {
    final bank = await account(AccountType.bank);
    final other = await account(AccountType.bank);
    final card = await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: bank.id),
    );
    for (final invalid in [
      purchase(other.id, card.id),
      purchase(bank.id, card.id, currency: Currency.usd),
      purchase(bank.id, 999),
    ]) {
      await expectLater(
        movements.createMovement(invalid),
        throwsA(isA<MovementValidationException>()),
      );
    }
    final snapshot = await movements.getSnapshot();
    expect(snapshot.movements, isEmpty);
    expect(snapshot.accounts.map((a) => a.currentBalance.minorUnits), [
      1000,
      1000,
    ]);
  });

  test('Restricciones SQL impiden vinculación y uso incompatibles', () async {
    final bank = await account(AccountType.bank);
    final other = await account(AccountType.bank);
    final cash = await account(AccountType.cash);
    final card = await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: bank.id),
    );
    final db = await database.database;
    await expectLater(
      db.insert('debit_cards', {
        'name': 'Débito sintético',
        'account_id': cash.id,
      }),
      throwsA(isA<DatabaseException>()),
    );
    for (final invalid in [
      {'type': 'income', 'account_id': bank.id},
      {'type': 'expense', 'account_id': other.id},
    ]) {
      await expectLater(
        db.insert('movements', {
          ...invalid,
          'debit_card_id': card.id,
          'amount_minor': 100,
          'currency': 'gtq',
          'occurred_on': '2026-11-02',
          'description': 'Prueba sintética',
        }),
        throwsA(isA<DatabaseException>()),
      );
    }
    await movements.createMovement(purchase(bank.id, card.id));
    await expectLater(
      db.update(
        'debit_cards',
        {'account_id': other.id},
        where: 'id = ?',
        whereArgs: [card.id],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.update(
        'accounts',
        {'type': 'cash'},
        where: 'id = ?',
        whereArgs: [bank.id],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.delete('debit_cards', where: 'id = ?', whereArgs: [card.id]),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      (await movements.getSnapshot()).accounts.first.currentBalance.minorUnits,
      900,
    );
  });

  test(
    'Una escritura fallida de tarjeta conserva cuentas y permite reintentar',
    () async {
      final bank = await account(AccountType.bank);
      final db = await database.database;
      await db.execute(
        "CREATE TRIGGER reject_card AFTER INSERT ON debit_cards BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END",
      );
      final details = DebitCardDetails(
        name: 'Débito sintético',
        accountId: bank.id,
      );
      await expectLater(
        accounts.createDebitCard(details),
        throwsA(isA<DatabaseException>()),
      );
      expect(await accounts.getDebitCards(), isEmpty);
      expect(
        (await accounts.getAccounts()).single.currentBalance.minorUnits,
        1000,
      );
      await db.execute('DROP TRIGGER reject_card');
      await accounts.createDebitCard(details);
      expect(await accounts.getDebitCards(), hasLength(1));
    },
  );
}
