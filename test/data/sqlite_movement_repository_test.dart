import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
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
    AccountType type,
    int balance, {
    Currency currency = Currency.gtq,
  }) => accounts.createAccount(
    AccountDetails(
      name: 'Cuenta sintética',
      type: type,
      openingBalance: Money(balance, currency),
      openingDate: DateTime(2026, 10, 1),
    ),
  );

  MovementDetails operation(
    MovementType type,
    int id,
    int amount, {
    int? other,
    DateTime? date,
    Currency currency = Currency.gtq,
  }) => MovementDetails(
    type: type,
    accountId: id,
    counterpartyAccountId: other,
    amount: Money(amount, currency),
    date: date ?? today,
    description: "Operación ' sintética",
  );

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_movements_test_',
    );
    path = p.join(directory.path, 'ledger.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(database);
    movements = SqliteMovementRepository(database, now: () => today);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });

  test('Migra desde esquema 1 conservando cuentas, saldos y claves', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    await old.insert('accounts', {
      'id': 42,
      'name': 'Cuenta anterior sintética',
      'type': 'bank',
      'currency': 'gtq',
      'opening_minor': 12345,
      'opening_date': '2026-10-01',
    });
    await old.close();
    final snapshot = await movements.getSnapshot();
    expect(snapshot.accounts.single.id, 42);
    expect(snapshot.accounts.single.currentBalance, Money(12345, Currency.gtq));
    expect(snapshot.movements, isEmpty);
    expect(
      await (await database.database).getVersion(),
      LocalDatabase.schemaVersion,
    );
    await movements.createMovement(operation(MovementType.expense, 42, 100));
    expect(
      (await accounts.getAccounts()).single.currentBalance,
      Money(12245, Currency.gtq),
    );
  });

  test(
    'Una migración fallida no borra ni cambia la versión anterior',
    () async {
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
        ),
      );
      await old.insert('accounts', {
        'name': 'Cuenta anterior sintética',
        'type': 'bank',
        'currency': 'gtq',
        'opening_minor': 100,
        'opening_date': '2026-10-01',
      });
      await old.execute('CREATE TABLE movements (sentinel TEXT)');
      await old.close();
      await expectLater(
        movements.getSnapshot(),
        throwsA(isA<DatabaseException>()),
      );
      final preserved = await databaseFactoryFfi.openDatabase(path);
      expect(await preserved.getVersion(), 1);
      expect(await preserved.query('accounts'), hasLength(1));
      expect((await preserved.query('accounts')).single['opening_minor'], 100);
      await preserved.close();
    },
  );

  test(
    'Compra y pago persisten una sola operación cada uno al reabrir',
    () async {
      final bank = await account(AccountType.bank, 100000);
      final credit = await account(AccountType.creditCard, 0);
      await movements.createMovement(
        operation(MovementType.expense, credit.id, 5000),
      );
      await movements.createMovement(
        operation(MovementType.creditPayment, bank.id, 2000, other: credit.id),
      );
      await database.close();
      final snapshot = await movements.getSnapshot();
      expect(
        snapshot.accounts.first.currentBalance,
        Money(98000, Currency.gtq),
      );
      expect(snapshot.accounts.last.currentBalance, Money(3000, Currency.gtq));
      expect(snapshot.movements, hasLength(2));
      expect(
        snapshot.movements.where((m) => m.details.isExpense),
        hasLength(1),
      );
      expect(snapshot.movements.where((m) => m.details.isIncome), isEmpty);
      expect(snapshot.movements.first.details.counterpartyAccountId, credit.id);
      expect(
        snapshot.movements.first.details.description,
        "Operación ' sintética",
      );
    },
  );

  test(
    'Transferencias actualizan ambas cuentas y mantienen los saldos iniciales',
    () async {
      final bank = await account(AccountType.bank, 100000);
      final cash = await account(AccountType.cash, 0);
      final snapshot = await movements.createMovement(
        operation(MovementType.transfer, bank.id, 2000, other: cash.id),
      );
      expect(snapshot.accounts.first.currentBalance.minorUnits, 98000);
      expect(snapshot.accounts.last.currentBalance.minorUnits, 2000);
      expect(snapshot.accounts.last.details.openingBalance.minorUnits, 0);
      expect(
        (await accounts.getAccounts()).last.currentBalance.minorUnits,
        2000,
      );
    },
  );

  test(
    'Un fallo SQL revierte el movimiento y conserva los dos saldos',
    () async {
      final bank = await account(AccountType.bank, 100000);
      final cash = await account(AccountType.cash, 0);
      final db = await database.database;
      await db.execute(
        '''CREATE TRIGGER reject_movement AFTER INSERT ON movements
      BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END''',
      );
      await expectLater(
        movements.createMovement(
          operation(MovementType.transfer, bank.id, 1000, other: cash.id),
        ),
        throwsA(isA<DatabaseException>()),
      );
      final snapshot = await movements.getSnapshot();
      expect(snapshot.movements, isEmpty);
      expect(snapshot.accounts.map((a) => a.currentBalance.minorUnits), [
        100000,
        0,
      ]);
    },
  );

  test(
    'Rechaza una operación retroactiva que dejaría efectivo negativo',
    () async {
      final cash = await account(AccountType.cash, 0);
      await movements.createMovement(
        operation(MovementType.income, cash.id, 1000),
      );
      await expectLater(
        movements.createMovement(
          operation(
            MovementType.expense,
            cash.id,
            500,
            date: DateTime(2026, 11, 1),
          ),
        ),
        throwsA(isA<MovementValidationException>()),
      );
      final snapshot = await movements.getSnapshot();
      expect(snapshot.movements, hasLength(1));
      expect(snapshot.accounts.single.currentBalance.minorUnits, 1000);
    },
  );

  test(
    'Valida moneda y fecha dentro del repositorio antes de guardar',
    () async {
      final bank = await account(AccountType.bank, 1000);
      final usd = await account(AccountType.bank, 0, currency: Currency.usd);
      for (final invalid in [
        operation(MovementType.transfer, bank.id, 1, other: usd.id),
        operation(
          MovementType.expense,
          bank.id,
          1,
          date: DateTime(2026, 11, 3),
        ),
        operation(
          MovementType.expense,
          bank.id,
          1,
          date: DateTime(2026, 9, 30),
        ),
        operation(MovementType.expense, 999, 1),
      ]) {
        await expectLater(
          movements.createMovement(invalid),
          throwsA(isA<MovementValidationException>()),
        );
      }
      expect((await movements.getSnapshot()).movements, isEmpty);
    },
  );

  test('Compras idénticas y escrituras simultáneas conservan todas sus identidades', () async {
    final bank = await account(AccountType.bank, 1000);
    await Future.wait([
      for (var i = 0; i < 5; i++)
        movements.createMovement(operation(MovementType.expense, bank.id, 29)),
    ]);
    final snapshot = await movements.getSnapshot();
    expect(snapshot.movements, hasLength(5));
    expect(snapshot.movements.map((m) => m.id).toSet(), hasLength(5));
    expect(snapshot.accounts.single.currentBalance.minorUnits, 855);
  });

  test(
    'El esquema exige referencias válidas y una contraparte coherente',
    () async {
      final bank = await account(AccountType.bank, 1000);
      final db = await database.database;
      final base = <String, Object?>{
        'type': 'expense',
        'account_id': bank.id,
        'amount_minor': 1,
        'currency': 'gtq',
        'occurred_on': '2026-11-02',
        'description': 'Prueba sintética',
      };
      for (final invalid in <Map<String, Object?>>[
        {'account_id': 999},
        {'amount_minor': 0},
        {'type': 'transfer'},
        {'type': 'creditPayment', 'counterparty_account_id': bank.id},
        {'counterparty_account_id': bank.id},
      ]) {
        await expectLater(
          db.insert('movements', {...base, ...invalid}),
          throwsA(isA<DatabaseException>()),
        );
      }
      expect((await movements.getSnapshot()).movements, isEmpty);
    },
  );
}
