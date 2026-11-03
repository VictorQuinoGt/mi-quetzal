import 'support/migration_expectations.dart';

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
import 'domain/multicurrency_account_test.dart' as multicurrency_tests;
import 'domain/financial_institution_test.dart' as financial_institution_tests;
import 'domain/account_activity_test.dart' as account_activity_tests;
import 'domain/installment_calendar_test.dart' as installment_calendar_tests;

import 'package:mi_quetzal/data/repositories/sqlite_installment_repository.dart';
import 'package:mi_quetzal/domain/models/installment_plan.dart';

import 'package:mi_quetzal/domain/models/financial_institution.dart';

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
    multicurrency_tests.main();
    financial_institution_tests.main();
    account_activity_tests.main();
    installment_calendar_tests.main();
  }
  test('SQLite web migra v8, recupera cuotas, redondea y concilia sin duplicar al reabrir', () async {
    final factory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
        sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
        indexedDbName: 'mi_quetzal_browser_tests',
      ),
    );
    final path =
        'test_installments_${DateTime.now().microsecondsSinceEpoch}.db';
    var now = DateTime(2026, 1, 30);
    final old = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    await old.insert('accounts', {
      'id': 1,
      'name': 'Crédito web sintético',
      'type': 'creditCard',
      'currency': 'gtq',
      'opening_minor': 0,
      'credit_limit_minor': 100000,
      'opening_date': '2025-01-01',
    });
    await old.close();
    final database = LocalDatabase(factory: factory, path: path);
    addTearDown(() async {
      await database.close();
      await factory.deleteDatabase(path);
    });
    final plans = SqliteInstallmentRepository(database, now: () => now);
    await plans.createPlan(
      InstallmentDraft(
        description: 'Plan web sintético',
        accountId: 1,
        originalAmount: Money(1000, Currency.gtq),
        count: 3,
        monthlyAmount: Money(333, Currency.gtq),
        firstDate: DateTime(2026, 1, 31),
        chargeDay: 31,
        previousCount: 0,
        referenceDate: now,
        costMode: InstallmentCostMode.noInterest,
        limitMode: InstallmentLimitMode.ordinary,
      ),
    );
    now = DateTime(2026, 4, 1);
    final snapshots = await Future.wait(
      List.generate(4, (_) => plans.generateDue()),
    );
    for (final snapshot in snapshots) {
      expect(snapshot.movements, hasLength(3));
      expect(snapshot.accounts.single.currentBalance.minorUnits, 1000);
      expect(
        snapshot.installmentPlans.single.state,
        InstallmentPlanState.completed,
      );
    }
    final movements = SqliteMovementRepository(database, now: () => now);
    final manual = await movements.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: 1,
        amount: Money(334, Currency.gtq),
        date: DateTime(2026, 3, 31),
        description: 'Cargo bancario sintético',
      ),
    );
    final source = manual.movements
        .firstWhere((m) => !m.details.isGenerated)
        .id;
    await plans.reconcile(1, 3, source, 'Referencia sintética');
    await database.close();
    final reopened = await movements.getSnapshot();
    expect(reopened.accounts.single.currentBalance.minorUnits, 1000);
    expect(
      MonthlySummary.calculate(
        reopened,
        2026,
        3,
      ).currencies.single.expense.minorUnits,
      334,
    );
    expect(
      await (await database.database).rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
  }, skip: !kIsWeb);
  test(
    'SQLite web migra v7 y conserva fechas completas independientes al reabrir',
    () async {
      final factory = createDatabaseFactoryFfiWeb(
        options: SqfliteFfiWebOptions(
          sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
          sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
          indexedDbName: 'mi_quetzal_browser_tests',
        ),
      );
      final path =
          'test_credit_dates_${DateTime.now().microsecondsSinceEpoch}.db';
      final database = LocalDatabase(factory: factory, path: path);
      addTearDown(() async {
        await database.close();
        await factory.deleteDatabase(path);
      });
      final old = await factory.openDatabase(
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
      final originalRows = await old.query('movements');
      await old.close();
      final accounts = SqliteAccountRepository(database);
      final migrated = (await accounts.getAccounts()).single;
      expect(migrated.details.nextClosingDate, isNull);
      expect(migrated.details.nextPaymentDueDate, isNull);
      await accounts.updateAccount(
        7,
        AccountDetails(
          name: 'Crédito actualizado',
          type: AccountType.creditCard,
          openingBalance: Money(1000, Currency.gtq),
          secondaryOpeningBalance: Money(2000, Currency.usd),
          creditLimit: Money(5000, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
          nextClosingDate: DateTime(2026, 11, 20),
          nextPaymentDueDate: DateTime(2026, 11, 5),
        ),
      );
      await database.close();
      final account = (await accounts.getAccounts()).single;
      expect(account.details.nextClosingDate, DateTime(2026, 11, 20));
      expect(account.details.nextPaymentDueDate, DateTime(2026, 11, 5));
      expect(account.currentBalance.minorUnits, 1000);
      expect(account.secondaryCurrentBalance!.minorUnits, 2125);
      expect(account.availableCreditFor(Currency.gtq)!.minorUnits, 4000);
      expect(account.availableCreditFor(Currency.usd), isNull);
      expectPreservedRows(
        await (await database.database).query('movements'),
        originalRows,
      );
    },
    skip: !kIsWeb,
  );
  test('SQLite web migra v6, conserva historial y persiste entidades y terminación bancaria', () async {
    final factory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
        sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
        indexedDbName: 'mi_quetzal_browser_tests',
      ),
    );
    final path =
        'test_institutions_${DateTime.now().microsecondsSinceEpoch}.db';
    final database = LocalDatabase(factory: factory, path: path);
    addTearDown(() async {
      await database.close();
      await factory.deleteDatabase(path);
    });
    final old = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    await old.insert('accounts', {
      'id': 7,
      'name': 'Banco anterior sintético',
      'type': 'bank',
      'currency': 'gtq',
      'opening_minor': 1000,
      'opening_date': '2026-10-01',
    });
    await old.insert('debit_cards', {
      'id': 9,
      'name': 'Débito anterior sintético',
      'account_id': 7,
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
    final originalRows = await old.query('movements');
    await old.close();
    final accounts = SqliteAccountRepository(database);
    final movements = SqliteMovementRepository(
      database,
      now: () => DateTime(2026, 11, 2),
    );
    final migrated = await movements.getSnapshot();
    expect(migrated.financialInstitutions, isEmpty);
    expect(migrated.accounts.single.details.lastFour, isNull);
    final entity = (await movements.createFinancialInstitution(
      FinancialInstitutionDetails(name: "Entidad ' sintética"),
    )).financialInstitutions.single;
    await accounts.updateAccount(
      7,
      AccountDetails(
        name: 'Banco actualizado sintético',
        type: AccountType.bank,
        openingBalance: Money(1000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
        financialInstitutionId: entity.id,
        lastFour: '0042',
      ),
    );
    await accounts.updateDebitCard(
      9,
      DebitCardDetails(
        name: 'Débito actualizado sintético',
        accountId: 7,
        financialInstitutionId: entity.id,
      ),
    );
    await database.close();
    final after = await movements.getSnapshot();
    expect(after.accounts.single.currentBalance.minorUnits, 875);
    expect(after.accounts.single.details.lastFour, '0042');
    expect(after.accounts.single.details.financialInstitutionId, entity.id);
    expect(after.debitCards.single.details.financialInstitutionId, entity.id);
    expect(
      after.financialInstitutions.single.details.name,
      "Entidad ' sintética",
    );
    final db = await database.database;
    expectPreservedRows(await db.query('movements'), originalRows);
    await expectLater(
      db.delete(
        'financial_institutions',
        where: 'id = ?',
        whereArgs: [entity.id],
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  }, skip: !kIsWeb);
  test('SQLite web migra v5, completa moneda de crédito y edita banco/débito sin alterar historial', () async {
    final factory = createDatabaseFactoryFfiWeb(
      options: SqfliteFfiWebOptions(
        sharedWorkerUri: Uri.parse('/web_assets/sqflite_sw.js'),
        sqlite3WasmUri: Uri.parse('/web_assets/sqlite3.wasm'),
        indexedDbName: 'mi_quetzal_browser_tests',
      ),
    );
    final path =
        'test_account_edit_${DateTime.now().microsecondsSinceEpoch}.db';
    final database = LocalDatabase(factory: factory, path: path);
    addTearDown(() async {
      await database.close();
      await factory.deleteDatabase(path);
    });
    final old = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    for (final entry in [
      (1, 'creditCard', 'gtq', 1000),
      (2, 'bank', 'usd', 10000),
    ]) {
      await old.insert('accounts', {
        'id': entry.$1,
        'name': 'Cuenta sintética',
        'type': entry.$2,
        'currency': entry.$3,
        'opening_minor': entry.$4,
        'opening_date': '2026-10-01',
      });
    }
    await old.insert('debit_cards', {
      'id': 7,
      'name': 'Débito sintético',
      'account_id': 2,
    });
    await old.insert('movements', {
      'id': 9,
      'type': 'expense',
      'account_id': 1,
      'amount_minor': 125,
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
    expect(
      (await accounts.getAccounts()).first.secondaryCurrentBalance,
      isNull,
    );
    await accounts.updateAccount(
      1,
      AccountDetails(
        name: 'Crédito actualizado',
        type: AccountType.creditCard,
        openingBalance: Money(1000, Currency.gtq),
        secondaryOpeningBalance: Money(2000, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await accounts.updateAccount(
      2,
      AccountDetails(
        name: 'Banco actualizado',
        type: AccountType.bank,
        bankAccountType: BankAccountType.savings,
        openingBalance: Money(10000, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await accounts.updateDebitCard(
      7,
      DebitCardDetails(
        name: 'Débito actualizado',
        accountId: 2,
        lastFour: '0042',
      ),
    );
    final expense = await movements.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: 1,
        amount: Money(500, Currency.usd),
        date: DateTime(2026, 11, 2),
        description: 'Compra USD sintética',
      ),
    );
    final originalId = expense.movements.first.id;
    await movements.createMovement(
      MovementDetails(
        type: MovementType.creditPayment,
        accountId: 2,
        counterpartyAccountId: 1,
        amount: Money(200, Currency.usd),
        date: DateTime(2026, 11, 2),
        description: 'Pago USD sintético',
      ),
    );
    await movements.createMovement(
      MovementDetails(
        type: MovementType.refund,
        accountId: 1,
        originalMovementId: originalId,
        amount: Money(100, Currency.usd),
        date: DateTime(2026, 11, 2),
        description: 'Devolución USD sintética',
      ),
    );
    await database.close();
    final after = await movements.getSnapshot();
    expect(after.accounts.first.currentBalance.minorUnits, 1125);
    expect(
      after.accounts.first.secondaryCurrentBalance,
      Money(2200, Currency.usd),
    );
    expect(after.accounts.last.currentBalance.minorUnits, 9800);
    expect(
      after.accounts.last.details.bankAccountType,
      BankAccountType.savings,
    );
    expect(after.debitCards.single.details.name, 'Débito actualizado');
    expect(after.debitCards.single.id, 7);
    expect(after.movements, hasLength(4));
    expect(after.movements.last.id, 9);
    final report = MonthlySummary.calculate(after, 2026, 11);
    expect(report.currencies.map((c) => c.expense.minorUnits), [125, 400]);
    expect(
      await (await database.database).rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
  }, skip: !kIsWeb);
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
