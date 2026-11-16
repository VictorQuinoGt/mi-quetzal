import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
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
  final today = DateTime(2026, 11, 15);
  final historical = DateTime(2026, 9, 30);

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mi_quetzal_historical_');
    path = p.join(directory.path, 'ledger.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(database, now: () => today);
    movements = SqliteMovementRepository(database, now: () => today);
    for (final entry in [
      (AccountType.bank, 100000, Currency.gtq),
      (AccountType.cash, 10000, Currency.gtq),
      (AccountType.creditCard, 5000, Currency.gtq),
      (AccountType.bank, 10000, Currency.usd),
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: 'Cuenta sintética ${entry.$1.name} ${entry.$3.name}',
          type: entry.$1,
          openingBalance: Money(entry.$2, entry.$3),
          secondaryOpeningBalance: entry.$1 == AccountType.creditCard
              ? Money(2000, Currency.usd)
              : null,
          openingDate: today,
        ),
      );
    }
    await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: 1),
    );
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });

  Future<LedgerSnapshot> record(
    MovementType type,
    int accountId,
    int amount, {
    Currency currency = Currency.gtq,
    int? other,
    int? debit,
    int? original,
    DateTime? date,
  }) => movements.createMovement(
    MovementDetails(
      type: type,
      accountId: accountId,
      counterpartyAccountId: other,
      debitCardId: debit,
      originalMovementId: original,
      amount: Money(amount, currency),
      date: date ?? historical,
      description: 'Movimiento histórico sintético',
    ),
  );

  test(
    'Compras anteriores al alta persisten y mantienen crédito GTQ/USD separado',
    () async {
      await record(MovementType.expense, 3, 300);
      await record(MovementType.expense, 3, 200, currency: Currency.usd);
      await database.close();
      final snapshot = await movements.getSnapshot();
      final credit = snapshot.accounts.singleWhere((a) => a.id == 3);
      expect(credit.currentBalance.minorUnits, 5300);
      expect(credit.secondaryCurrentBalance!.minorUnits, 2200);
      expect(credit.details.openingBalance.minorUnits, 5000);
      expect(credit.details.secondaryOpeningBalance!.minorUnits, 2000);
      expect(credit.details.openingDate, today);
      expect(
        snapshot.movements.map((m) => m.details.date),
        everyElement(historical),
      );
      expect(snapshot.movements, hasLength(2));
    },
  );

  test(
    'Débito histórico descuenta una vez y el ingreso suma al banco vinculado',
    () async {
      await record(MovementType.expense, 1, 250, debit: 1);
      final snapshot = await record(MovementType.income, 1, 500);
      expect(snapshot.accounts.first.currentBalance.minorUnits, 100250);
      expect(
        snapshot.movements.where((m) => m.details.debitCardId == 1),
        hasLength(1),
      );
      final summary = MonthlySummary.calculate(
        snapshot,
        2026,
        9,
      ).currencies.single;
      expect(summary.expense.minorUnits, 250);
      expect(summary.income.minorUnits, 500);
    },
  );

  test('Pagos y transferencias anteriores al alta afectan ambas cuentas sin gasto extra', () async {
    await record(MovementType.creditPayment, 1, 1000, other: 3);
    final snapshot = await record(MovementType.transfer, 1, 2000, other: 2);
    expect(
      snapshot.accounts.singleWhere((a) => a.id == 1).currentBalance.minorUnits,
      97000,
    );
    expect(
      snapshot.accounts.singleWhere((a) => a.id == 2).currentBalance.minorUnits,
      12000,
    );
    expect(
      snapshot.accounts.singleWhere((a) => a.id == 3).currentBalance.minorUnits,
      4000,
    );
    expect(MonthlySummary.calculate(snapshot, 2026, 9).currencies, isEmpty);
    expect(snapshot.movements, hasLength(2));
  });

  test('Devolución histórica conserva el vínculo y rechaza fechas anteriores a la compra', () async {
    final purchase = await record(MovementType.expense, 3, 300);
    final id = purchase.movements.single.id;
    final snapshot = await record(
      MovementType.refund,
      3,
      100,
      original: id,
      date: historical.add(const Duration(days: 1)),
    );
    expect(
      snapshot.accounts.singleWhere((a) => a.id == 3).currentBalance.minorUnits,
      5200,
    );
    await expectLater(
      record(
        MovementType.refund,
        3,
        100,
        original: id,
        date: historical.subtract(const Duration(days: 1)),
      ),
      throwsA(isA<MovementValidationException>()),
    );
    expect((await movements.getSnapshot()).movements, hasLength(2));
  });

  test(
    'Efectivo se valida en orden histórico y un fallo revierte la escritura',
    () async {
      await record(MovementType.income, 2, 10000, date: DateTime(2026, 10, 1));
      await expectLater(
        record(MovementType.expense, 2, 15000),
        throwsA(isA<MovementValidationException>()),
      );
      final snapshot = await movements.getSnapshot();
      expect(
        snapshot.accounts
            .singleWhere((a) => a.id == 2)
            .currentBalance
            .minorUnits,
        20000,
      );
      expect(snapshot.movements, hasLength(1));
    },
  );
}
