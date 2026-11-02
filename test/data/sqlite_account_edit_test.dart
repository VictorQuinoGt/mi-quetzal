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
  AccountDetails details({
    AccountType type = AccountType.creditCard,
    String name = 'Cuenta sintética',
    int opening = 1000,
    int? secondary,
    DateTime? date,
    BankAccountType? bankType,
  }) => AccountDetails(
    name: name,
    type: type,
    openingBalance: Money(opening, Currency.gtq),
    secondaryOpeningBalance: secondary == null
        ? null
        : Money(secondary, Currency.usd),
    secondaryCreditLimit: secondary == null
        ? null
        : Money(200000, Currency.usd),
    bankAccountType: bankType,
    openingDate: date ?? DateTime(2026, 10, 1),
  );
  Future<void> record(
    int id,
    Currency currency,
    int cents, {
    int? debit,
  }) async {
    await movements.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: id,
        debitCardId: debit,
        amount: Money(cents, currency),
        date: DateTime(2026, 11, 1),
        description: 'Compra sintética',
      ),
    );
  }

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_account_edit_',
    );
    path = p.join(directory.path, 'accounts.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(database, now: () => today);
    movements = SqliteMovementRepository(database, now: () => today);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });
  test('Migra v5 sin inventar segunda deuda ni tipo de banco y permite completar cuentas', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    for (final entry in [
      (7, 'creditCard', 'usd', 1250),
      (8, 'bank', 'gtq', 10000),
    ]) {
      await old.insert('accounts', {
        'id': entry.$1,
        'name': 'Cuenta anterior sintética',
        'type': entry.$2,
        'currency': entry.$3,
        'opening_minor': entry.$4,
        'opening_date': '2026-10-01',
      });
    }
    await old.insert('movements', {
      'id': 42,
      'type': 'expense',
      'account_id': 7,
      'amount_minor': 29,
      'currency': 'usd',
      'occurred_on': '2026-11-01',
      'description': 'Compra anterior sintética',
    });
    await old.close();
    final migrated = await movements.getSnapshot();
    expect(migrated.accounts.first.currentBalance, Money(1279, Currency.usd));
    expect(migrated.accounts.first.secondaryCurrentBalance, isNull);
    expect(migrated.accounts.last.details.bankAccountType, isNull);
    final updated = await accounts.updateAccount(
      7,
      AccountDetails(
        name: 'Crédito actualizado',
        type: AccountType.creditCard,
        openingBalance: Money(1250, Currency.usd),
        secondaryOpeningBalance: Money(2000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    expect(updated.id, 7);
    expect(updated.currentBalance.minorUnits, 1279);
    expect(updated.secondaryCurrentBalance, Money(2000, Currency.gtq));
    expect((await movements.getSnapshot()).movements.single.id, 42);
  });
  test('Fallo de migración conserva base y versión v5', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    await old.insert('accounts', {
      'name': 'Banco sintético',
      'type': 'bank',
      'currency': 'gtq',
      'opening_minor': 29,
      'opening_date': '2026-10-01',
    });
    await old.execute('ALTER TABLE accounts ADD COLUMN bank_account_type TEXT');
    await old.close();
    await expectLater(
      accounts.getAccounts(),
      throwsA(isA<DatabaseException>()),
    );
    final preserved = await databaseFactoryFfi.openDatabase(path);
    expect(await preserved.getVersion(), 5);
    expect((await preserved.query('accounts')).single['opening_minor'], 29);
    await preserved.close();
  });
  test('Editar crédito recalcula ambas monedas, conserva movimientos y persiste tras reabrir', () async {
    final card = await accounts.createAccount(details(secondary: 2000));
    await record(card.id, Currency.gtq, 100);
    await record(card.id, Currency.usd, 200);
    final before = await (await database.database).query('movements');
    final updated = await accounts.updateAccount(
      card.id,
      details(name: 'Alias actualizado', opening: 5000, secondary: 6000),
    );
    expect(updated.currentBalance.minorUnits, 5100);
    expect(updated.secondaryCurrentBalance!.minorUnits, 6200);
    expect(await (await database.database).query('movements'), before);
    await database.close();
    final after = (await accounts.getAccounts()).single;
    expect(after.details.name, 'Alias actualizado');
    expect(after.secondaryCurrentBalance!.minorUnits, 6200);
    expect(after.details.secondaryCreditLimit!.minorUnits, 200000);
  });
  test('Fecha incompatible, futuro, moneda con historial y efectivo negativo revierten edición', () async {
    final card = await accounts.createAccount(details(secondary: 2000));
    await record(card.id, Currency.usd, 100);
    for (final candidate in [
      details(secondary: 2000, date: today),
      details(secondary: 2000, date: DateTime(2026, 11, 3)),
      details(),
    ]) {
      await expectLater(
        accounts.updateAccount(card.id, candidate),
        throwsArgumentError,
      );
      expect(
        (await accounts.getAccounts())
            .single
            .details
            .secondaryOpeningBalance!
            .minorUnits,
        2000,
      );
    }
    final cash = await accounts.createAccount(details(type: AccountType.cash));
    await record(cash.id, Currency.gtq, 900);
    await expectLater(
      accounts.updateAccount(
        cash.id,
        details(type: AccountType.cash, opening: 899),
      ),
      throwsArgumentError,
    );
    expect((await accounts.getAccounts()).last.currentBalance.minorUnits, 100);
  });
  test('Editar banco actualiza tipo y saldo compartido sin duplicar fondos de débito', () async {
    final bank = await accounts.createAccount(
      details(type: AccountType.bank, bankType: BankAccountType.monetary),
    );
    final card = await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: bank.id),
    );
    await record(bank.id, Currency.gtq, 100, debit: card.id);
    final updated = await accounts.updateAccount(
      bank.id,
      details(
        type: AccountType.bank,
        opening: 2000,
        bankType: BankAccountType.savings,
      ),
    );
    expect(updated.currentBalance.minorUnits, 1900);
    expect(updated.details.bankAccountType, BankAccountType.savings);
    final debit = await accounts.updateDebitCard(
      card.id,
      DebitCardDetails(
        name: 'Débito actualizado',
        accountId: bank.id,
        lastFour: '0042',
      ),
    );
    expect(debit.id, card.id);
    final snapshot = await movements.getSnapshot();
    expect(snapshot.accounts, hasLength(1));
    expect(snapshot.movements.single.details.debitCardId, card.id);
    expect(snapshot.debitCards.single.details.lastFour, '0042');
    await database.close();
    expect(
      (await accounts.getDebitCards()).single.details.name,
      'Débito actualizado',
    );
  });
  test('No reasigna una tarjeta de débito usada a otro banco', () async {
    final first = await accounts.createAccount(details(type: AccountType.bank));
    final second = await accounts.createAccount(
      details(type: AccountType.bank),
    );
    final card = await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: first.id),
    );
    await record(first.id, Currency.gtq, 100, debit: card.id);
    await expectLater(
      accounts.updateDebitCard(
        card.id,
        DebitCardDetails(name: 'Alias cambiado', accountId: second.id),
      ),
      throwsA(isA<DebitCardValidationException>()),
    );
    expect((await accounts.getDebitCards()).single.details.accountId, first.id);
    expect(
      (await accounts.getDebitCards()).single.details.name,
      'Débito sintético',
    );
  });
  test('SQL rechaza tipo bancario o segunda deuda incompatible', () async {
    final card = await accounts.createAccount(details());
    final bank = await accounts.createAccount(details(type: AccountType.bank));
    final db = await database.database;
    for (final change in [
      (card.id, {'bank_account_type': 'savings'}),
      (bank.id, {'secondary_opening_minor': 0}),
      (card.id, {'secondary_opening_minor': -1}),
      (card.id, {'secondary_credit_limit_minor': 100}),
      (bank.id, {'bank_account_type': 'otro'}),
    ]) {
      await expectLater(
        db.update(
          'accounts',
          change.$2,
          where: 'id = ?',
          whereArgs: [change.$1],
        ),
        throwsA(isA<DatabaseException>()),
      );
    }
  });
}
