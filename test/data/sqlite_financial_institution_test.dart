import '../support/migration_expectations.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/financial_institution.dart';
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
  final date = DateTime(2026, 11, 2);
  AccountDetails bank({
    int? entity,
    String? digits,
    String name = 'Banco sintético',
  }) => AccountDetails(
    name: name,
    type: AccountType.bank,
    openingBalance: Money(1000, Currency.gtq),
    openingDate: DateTime(2026, 10, 1),
    financialInstitutionId: entity,
    lastFour: digits,
  );
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_institutions_',
    );
    path = p.join(directory.path, 'institutions.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(database, now: () => date);
    movements = SqliteMovementRepository(database, now: () => date);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });
  Future<Database> oldDatabase() async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    for (final row in [
      {'id': 7, 'type': 'bank', 'opening_minor': 1000},
      {
        'id': 8,
        'type': 'creditCard',
        'opening_minor': 500,
        'secondary_opening_minor': 2000,
        'last_four': '0042',
      },
    ]) {
      await old.insert('accounts', {
        ...row,
        'name': 'Cuenta anterior sintética',
        'currency': 'gtq',
        'opening_date': '2026-10-01',
      });
    }
    await old.insert('debit_cards', {
      'id': 9,
      'name': 'Débito anterior sintético',
      'account_id': 7,
      'last_four': '0027',
    });
    await old.insert('movements', {
      'id': 42,
      'type': 'expense',
      'account_id': 7,
      'debit_card_id': 9,
      'amount_minor': 125,
      'currency': 'gtq',
      'occurred_on': '2026-11-01',
      'description': 'Compra anterior sintética',
    });
    return old;
  }

  test('Migra v6 conservando cuentas, débito e historial sin inferir entidades ni terminaciones', () async {
    final old = await oldDatabase();
    final rows = await old.query('movements');
    await old.close();
    final snapshot = await movements.getSnapshot();
    expect(snapshot.accounts.first.currentBalance.minorUnits, 875);
    expect(snapshot.accounts.first.details.lastFour, isNull);
    expect(snapshot.accounts.last.details.lastFour, '0042');
    expect(snapshot.accounts.last.secondaryCurrentBalance!.minorUnits, 2000);
    expect(snapshot.financialInstitutions, isEmpty);
    expect(snapshot.debitCards.single.id, 9);
    expect(snapshot.accounts.map((a) => a.details.financialInstitutionId), [
      null,
      null,
    ]);
    expectPreservedRows(
      await (await database.database).query('movements'),
      rows,
    );
  });
  test('Fallo de migración conserva versión y filas anteriores', () async {
    final old = await oldDatabase();
    await old.execute('CREATE TABLE financial_institutions (sentinel TEXT)');
    await old.close();
    await expectLater(
      movements.getSnapshot(),
      throwsA(isA<DatabaseException>()),
    );
    final preserved = await databaseFactoryFfi.openDatabase(path);
    expect(await preserved.getVersion(), 6);
    expect((await preserved.query('accounts')).length, 2);
    expect((await preserved.query('movements')).single['id'], 42);
    await preserved.close();
  });
  test('Catálogo y asignaciones persisten sin cambiar saldos o movimientos al editar', () async {
    final snapshot = await movements.createFinancialInstitution(
      FinancialInstitutionDetails(name: "Entidad ' sintética"),
    );
    final institutionId = snapshot.financialInstitutions.single.id;
    final account = await accounts.createAccount(bank());
    final debit = await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: account.id),
    );
    await movements.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: account.id,
        debitCardId: debit.id,
        amount: Money(125, Currency.gtq),
        date: date,
        description: "Compra ' sintética",
      ),
    );
    final before = await (await database.database).query('movements');
    final updated = await accounts.updateAccount(
      account.id,
      bank(entity: institutionId, digits: '0042'),
    );
    expect(updated.currentBalance.minorUnits, 875);
    await accounts.updateDebitCard(
      debit.id,
      DebitCardDetails(
        name: 'Débito actualizado',
        accountId: account.id,
        financialInstitutionId: institutionId,
      ),
    );
    await database.close();
    final after = await movements.getSnapshot();
    expect(after.accounts.single.details.lastFour, '0042');
    expect(after.accounts.single.details.financialInstitutionId, institutionId);
    expect(
      after.debitCards.single.details.financialInstitutionId,
      institutionId,
    );
    expect(
      after.financialInstitutions.single.details.name,
      "Entidad ' sintética",
    );
    expect(await (await database.database).query('movements'), before);
    expect(
      (await accounts.getFinancialInstitutions()).single.id,
      institutionId,
    );
  });
  test('Entidades y terminaciones distinguen bancos con el mismo alias sin fusionar cuentas', () async {
    final institutionId = (await movements.createFinancialInstitution(
      FinancialInstitutionDetails(name: 'Entidad sintética'),
    )).financialInstitutions.single.id;
    for (final digits in ['0042', '0043']) {
      await accounts.createAccount(bank(entity: institutionId, digits: digits));
    }
    final rows = await accounts.getAccounts();
    expect(rows.map((a) => a.details.lastFour), ['0042', '0043']);
    expect(rows.map((a) => a.id).toSet(), hasLength(2));
    expect(rows.map((a) => a.currentBalance.minorUnits), [1000, 1000]);
  });
  test(
    'Referencias inválidas y restricciones SQL no dejan asignaciones parciales',
    () async {
      await expectLater(
        accounts.createAccount(bank(entity: 999)),
        throwsArgumentError,
      );
      final account = await accounts.createAccount(bank());
      await expectLater(
        accounts.createDebitCard(
          DebitCardDetails(
            name: 'Débito sintético',
            accountId: account.id,
            financialInstitutionId: 999,
          ),
        ),
        throwsA(isA<DebitCardValidationException>()),
      );
      final db = await database.database;
      for (final values in [
        {'financial_institution_id': 999},
        {'bank_last_four': '123'},
        {'bank_last_four': 'abcd'},
      ]) {
        await expectLater(
          db.update(
            'accounts',
            values,
            where: 'id = ?',
            whereArgs: [account.id],
          ),
          throwsA(isA<DatabaseException>()),
        );
      }
      expect(
        (await accounts.getAccounts()).single.details.financialInstitutionId,
        isNull,
      );
      expect(await accounts.getDebitCards(), isEmpty);
    },
  );
  test('Una entidad asignada no se elimina; fallo de escritura permite reintentar sin duplicar', () async {
    final db = await database.database;
    await db.execute(
      "CREATE TRIGGER reject_entity BEFORE INSERT ON financial_institutions BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END",
    );
    final details = FinancialInstitutionDetails(name: 'Entidad sintética');
    await expectLater(
      movements.createFinancialInstitution(details),
      throwsA(isA<DatabaseException>()),
    );
    expect(await accounts.getFinancialInstitutions(), isEmpty);
    await db.execute('DROP TRIGGER reject_entity');
    final id = (await movements.createFinancialInstitution(details))
        .financialInstitutions
        .single
        .id;
    await accounts.createAccount(bank(entity: id));
    await expectLater(
      db.delete('financial_institutions', where: 'id = ?', whereArgs: [id]),
      throwsA(isA<DatabaseException>()),
    );
    expect(await accounts.getFinancialInstitutions(), hasLength(1));
  });
}
