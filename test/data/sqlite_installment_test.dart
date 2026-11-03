import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_installment_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/installment_plan.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/monthly_summary.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/migration_expectations.dart';

void main() {
  late Directory directory;
  late String path;
  late LocalDatabase database;
  late SqliteAccountRepository accounts;
  late SqliteMovementRepository movements;
  late SqliteInstallmentRepository plans;
  late DateTime now;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    now = DateTime(2026, 1, 30);
    directory = await Directory.systemTemp.createTemp(
      'mi_quetzal_installments_',
    );
    path = p.join(directory.path, 'plans.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    accounts = SqliteAccountRepository(database, now: () => now);
    movements = SqliteMovementRepository(database, now: () => now);
    plans = SqliteInstallmentRepository(database, now: () => now);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });
  Future<void> seed({int opening = 0}) async {
    await accounts.createAccount(
      AccountDetails(
        name: 'Crédito sintético',
        type: AccountType.creditCard,
        openingBalance: Money(opening, Currency.gtq),
        creditLimit: Money(100000, Currency.gtq),
        secondaryOpeningBalance: Money(0, Currency.usd),
        secondaryCreditLimit: Money(100000, Currency.usd),
        openingDate: DateTime(2025, 1, 1),
      ),
    );
    await accounts.createAccount(
      AccountDetails(
        name: 'Banco sintético',
        type: AccountType.bank,
        openingBalance: Money(100000, Currency.gtq),
        openingDate: DateTime(2025, 1, 1),
      ),
    );
  }

  test('Migración v8 conserva registros y fechas; un fallo revierte todo y permite reintentar', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
      ),
    );
    await old.insert('accounts', {
      'id': 1,
      'name': 'Crédito sintético',
      'type': 'creditCard',
      'currency': 'gtq',
      'opening_minor': 1000,
      'opening_date': '2025-01-01',
      'next_closing_date': '2026-02-09',
      'next_payment_due_date': '2026-02-04',
    });
    await old.insert('movements', {
      'id': 11,
      'type': 'expense',
      'account_id': 1,
      'amount_minor': 125,
      'currency': 'gtq',
      'occurred_on': '2026-01-01',
      'description': 'Compra sintética anterior',
    });
    final before = await old.query('movements');
    await old.close();
    await expectLater(
      databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 9,
          onUpgrade: (db, from, to) async {
            await LocalDatabase.migrate(db, from, to);
            throw StateError('Fallo sintético después de migrar');
          },
        ),
      ),
      throwsA(anything),
    );
    final rolledBack = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 8),
    );
    expect(await rolledBack.getVersion(), 8);
    expect(
      await rolledBack.rawQuery(
        "SELECT name FROM sqlite_master WHERE name = 'installment_plans'",
      ),
      isEmpty,
    );
    expect(await rolledBack.query('movements'), before);
    await rolledBack.close();
    final snapshot = await movements.getSnapshot();
    expect(snapshot.installmentPlans, isEmpty);
    expect(snapshot.accounts.single.currentBalance.minorUnits, 1125);
    expect(
      snapshot.accounts.single.details.nextClosingDate,
      DateTime(2026, 2, 9),
    );
    expect(
      snapshot.accounts.single.details.nextPaymentDueDate,
      DateTime(2026, 2, 4),
    );
    expectPreservedRows(
      await (await database.database).query('movements'),
      before,
    );
    expect(
      await (await database.database).rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
  });

  InstallmentDraft draft({
    int original = 1000,
    int count = 3,
    int monthly = 333,
    int previous = 0,
    DateTime? first,
    DateTime? reference,
    int day = 31,
    InstallmentCostMode costs = InstallmentCostMode.noInterest,
    InstallmentLimitMode limit = InstallmentLimitMode.ordinary,
    int? principal,
    int? interest,
    int? fee,
    int? originalId,
    Currency currency = Currency.gtq,
    String description = 'Compra sintética',
  }) => InstallmentDraft(
    description: description,
    accountId: 1,
    originalAmount: Money(original, currency),
    count: count,
    monthlyAmount: Money(monthly, currency),
    firstDate: first ?? DateTime(2026, 1, 31),
    chargeDay: day,
    previousCount: previous,
    referenceDate: reference ?? DateTime(2026, 1, 30),
    costMode: costs,
    limitMode: limit,
    monthlyPrincipal: principal == null ? null : Money(principal, currency),
    monthlyInterest: interest == null ? null : Money(interest, currency),
    monthlyFee: fee == null ? null : Money(fee, currency),
    originalMovementId: originalId,
  );
  Future<void> manual(
    int cents, {
    MovementType type = MovementType.expense,
    int account = 1,
    int? other,
  }) async {
    await movements.createMovement(
      MovementDetails(
        type: type,
        accountId: account,
        counterpartyAccountId: other,
        amount: Money(cents, Currency.gtq),
        date: now,
        description: 'Cargo bancario importado sintético',
      ),
    );
  }

  test(
    'Carga por meses, ajusta última cuota y mueve reserva a deuda una sola vez',
    () async {
      await seed();
      var snapshot = await plans.createPlan(draft());
      expect(snapshot.accounts.first.currentBalance.minorUnits, 0);
      expect(
        snapshot.accounts.first.availableCreditFor(Currency.gtq)!.minorUnits,
        99000,
      );
      now = DateTime(2026, 1, 31);
      snapshot = await plans.generateDue();
      expect(snapshot.accounts.first.currentBalance.minorUnits, 333);
      expect(
        snapshot.accounts.first.reservedCredit[Currency.gtq]!.minorUnits,
        667,
      );
      expect(
        snapshot.accounts.first.availableCreditFor(Currency.gtq)!.minorUnits,
        99000,
      );
      expect(snapshot.movements, hasLength(1));
      now = DateTime(2026, 3, 31);
      snapshot = await plans.generateDue();
      expect(snapshot.installmentPlans.single.schedule.map((i) => i.date), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
      ]);
      expect(
        snapshot.installmentPlans.single.schedule.map(
          (i) => i.amount.minorUnits,
        ),
        [333, 333, 334],
      );
      expect(snapshot.accounts.first.currentBalance.minorUnits, 1000);
      expect(
        snapshot.installmentPlans.single.state,
        InstallmentPlanState.completed,
      );
      expect(snapshot.installmentPlans.single.nextDate, isNull);
    },
  );
  test('Reintentos y llamadas concurrentes recuperan meses sin duplicación persistente', () async {
    await seed();
    await plans.createPlan(draft());
    now = DateTime(2026, 5, 31);
    await Future.wait([for (var i = 0; i < 6; i++) plans.generateDue()]);
    await database.close();
    final snapshot = await movements.getSnapshot();
    expect(snapshot.movements, hasLength(3));
    expect(snapshot.movements.map((m) => m.details.installmentNumber).toSet(), {
      1,
      2,
      3,
    });
    expect(
      (await accounts.getAccounts()).first.currentBalance.minorUnits,
      1000,
    );
    expect(
      await (await database.database).rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
  });
  test('Planes GTQ y USD de una tarjeta conservan cargos y reservas independientes', () async {
    await seed();
    await plans.createPlan(draft());
    await plans.createPlan(
      draft(original: 2000, monthly: 666, currency: Currency.usd),
    );
    now = DateTime(2026, 1, 31);
    final snapshot = await plans.generateDue();
    final card = snapshot.accounts.first;
    expect(card.currentBalance.minorUnits, 333);
    expect(card.secondaryCurrentBalance!.minorUnits, 666);
    expect(card.reservedCredit[Currency.gtq]!.minorUnits, 667);
    expect(card.reservedCredit[Currency.usd]!.minorUnits, 1334);
    expect(card.availableCreditFor(Currency.gtq)!.minorUnits, 99000);
    expect(card.availableCreditFor(Currency.usd)!.minorUnits, 98000);
    expect(snapshot.movements.map((m) => m.details.installmentPlanId).toSet(), {
      1,
      2,
    });
  });
  test('Conexión de worker y UI compiten sin duplicados y cerrar worker conserva UI', () async {
    await seed();
    await plans.createPlan(draft());
    final workerDatabase = LocalDatabase(
      factory: databaseFactoryFfi,
      path: path,
      singleInstance: false,
    );
    final worker = SqliteInstallmentRepository(workerDatabase, now: () => now);
    await workerDatabase.database;
    now = DateTime(2026, 4, 30);
    Future<void> attempt(SqliteInstallmentRepository repository) async {
      try {
        await repository.generateDue();
      } on DatabaseException {
        // Una conexión ocupada puede solicitar reintento; nunca confirma parcialmente.
      }
    }

    try {
      await Future.wait([attempt(plans), attempt(worker)]);
    } finally {
      await workerDatabase.close();
    }
    final snapshot = await plans.generateDue();
    expect(snapshot.movements, hasLength(3));
    expect(snapshot.accounts.first.currentBalance.minorUnits, 1000);
    expect(
      snapshot.installmentPlans.single.state,
      InstallmentPlanState.completed,
    );
  });
  test(
    'Editar plan sin desglose rechaza otra moneda y conserva el calendario',
    () async {
      await seed();
      await plans.createPlan(
        draft(count: 4, monthly: 300, costs: InstallmentCostMode.unknown),
      );
      final db = await database.database;
      final before = await db.query('installments');
      await expectLater(
        plans.reviseFuture(
          1,
          description: 'Cambio inválido',
          categoryId: null,
          monthly: Money(300, Currency.usd),
          nextDate: DateTime(2026, 1, 31),
          chargeDay: 31,
        ),
        throwsA(isA<InstallmentValidationException>()),
      );
      expect(await db.query('installments'), before);
      expect(await db.query('installment_revisions'), isEmpty);
    },
  );
  test(
    'Plan previamente iniciado no duplica cuotas previas ni apertura',
    () async {
      now = DateTime(2026, 3, 31);
      await seed(opening: 500);
      final snapshot = await plans.createPlan(
        draft(
          original: 1000,
          count: 4,
          monthly: 250,
          previous: 2,
          reference: DateTime(2026, 2, 28),
        ),
      );
      expect(snapshot.movements, hasLength(1));
      expect(snapshot.movements.single.details.installmentNumber, 3);
      expect(snapshot.accounts.first.currentBalance.minorUnits, 750);
      expect(snapshot.installmentPlans.single.loadedCount, 3);
      expect(
        snapshot.installmentPlans.single.schedule
            .take(2)
            .every((i) => i.previouslyLoaded && i.movementId == null),
        isTrue,
      );
    },
  );
  test(
    'Desglose fijo conserva capital, interés y comisión sin estimar tasas',
    () async {
      await seed();
      await plans.createPlan(
        draft(
          count: 5,
          monthly: 225,
          costs: InstallmentCostMode.fixedBreakdown,
          principal: 200,
          interest: 20,
          fee: 5,
        ),
      );
      now = DateTime(2026, 1, 31);
      final snapshot = await plans.generateDue();
      expect(snapshot.accounts.first.currentBalance.minorUnits, 225);
      expect(
        snapshot.accounts.first.reservedCredit[Currency.gtq]!.minorUnits,
        800,
      );
      expect(
        snapshot.accounts.first.availableCreditFor(Currency.gtq)!.minorUnits,
        98975,
      );
      expect(
        snapshot.installmentPlans.single.schedule.first.interest!.minorUnits,
        20,
      );
      expect(
        MonthlySummary.calculate(
          snapshot,
          2026,
          1,
        ).currencies.single.expense.minorUnits,
        225,
      );
    },
  );
  test('Desglose desconocido no inventa capital ni disponible del límite ordinario', () async {
    await seed();
    final snapshot = await plans.createPlan(
      draft(count: 4, monthly: 300, costs: InstallmentCostMode.unknown),
    );
    expect(snapshot.installmentPlans.single.pendingPrincipal, isNull);
    expect(snapshot.accounts.first.availableCreditFor(Currency.gtq), isNull);
    expect(
      snapshot.accounts.first.availableCreditFor(Currency.usd)!.minorUnits,
      100000,
    );
  });
  test('Línea adicional no reduce límite ordinario; pago sin asignación deja disponible indeterminado', () async {
    await seed();
    await plans.createPlan(draft(limit: InstallmentLimitMode.additional));
    now = DateTime(2026, 1, 31);
    var snapshot = await plans.generateDue();
    expect(snapshot.accounts.first.currentBalance.minorUnits, 333);
    expect(
      snapshot.accounts.first.availableCreditFor(Currency.gtq)!.minorUnits,
      100000,
    );
    await manual(100, type: MovementType.creditPayment, account: 2, other: 1);
    snapshot = await movements.getSnapshot();
    expect(snapshot.accounts.first.currentBalance.minorUnits, 233);
    expect(snapshot.accounts.first.availableCreditFor(Currency.gtq), isNull);
  });
  test('Compra completa vinculada conserva gasto y no duplica deuda con cada mensualidad', () async {
    await seed();
    now = DateTime(2026, 1, 15);
    await manual(1000);
    var snapshot = await plans.createPlan(draft(reference: now, originalId: 1));
    expect(snapshot.accounts.first.currentBalance.minorUnits, 0);
    expect(
      snapshot.accounts.first.availableCreditFor(Currency.gtq)!.minorUnits,
      99000,
    );
    expect(
      MonthlySummary.calculate(
        snapshot,
        2026,
        1,
      ).currencies.single.expense.minorUnits,
      1000,
    );
    now = DateTime(2026, 3, 31);
    snapshot = await plans.generateDue();
    expect(snapshot.accounts.first.currentBalance.minorUnits, 1000);
    expect(MonthlySummary.calculate(snapshot, 2026, 2).currencies, isEmpty);
    expect(
      snapshot.movements
          .where((m) => m.details.origin == MovementOrigin.installmentCharge)
          .every((m) => m.details.recognizedExpenseMinor == 0),
      isTrue,
    );
  });
  test(
    'Descripción máxima conserva el plan y cabe en el movimiento de conversión',
    () async {
      await seed();
      now = DateTime(2026, 1, 15);
      await manual(1000);
      final description = List.filled(100, 'A').join();
      final snapshot = await plans.createPlan(
        draft(reference: now, originalId: 1, description: description),
      );
      expect(snapshot.installmentPlans.single.draft.description, description);
      expect(
        snapshot.movements
            .firstWhere(
              (m) => m.details.origin == MovementOrigin.installmentConversion,
            )
            .details
            .description
            .length,
        lessThanOrEqualTo(120),
      );
    },
  );
  test('Compra vinculada solo suma gastos financieros conocidos al gasto ya reconocido', () async {
    await seed();
    now = DateTime(2026, 1, 15);
    await manual(1000);
    await plans.createPlan(
      draft(
        count: 5,
        monthly: 225,
        costs: InstallmentCostMode.fixedBreakdown,
        principal: 200,
        interest: 20,
        fee: 5,
        originalId: 1,
        reference: now,
      ),
    );
    now = DateTime(2026, 1, 31);
    final snapshot = await plans.generateDue();
    expect(snapshot.accounts.first.currentBalance.minorUnits, 225);
    expect(
      MonthlySummary.calculate(
        snapshot,
        2026,
        1,
      ).currencies.single.expense.minorUnits,
      1025,
    );
  });
  test(
    'Cancelar detiene cargos futuros sin eliminar movimientos cargados',
    () async {
      await seed();
      await plans.createPlan(draft());
      now = DateTime(2026, 1, 31);
      await plans.generateDue();
      await plans.cancelPlan(1);
      now = DateTime(2026, 12, 31);
      final snapshot = await plans.generateDue();
      expect(snapshot.movements, hasLength(1));
      expect(snapshot.accounts.first.currentBalance.minorUnits, 333);
      expect(
        snapshot.installmentPlans.single.state,
        InstallmentPlanState.cancelled,
      );
      expect(snapshot.installmentPlans.single.pendingAmount.minorUnits, 0);
    },
  );
  test('Conciliar importado conserva referencias y elimina el doble efecto sin borrar filas', () async {
    await seed();
    await plans.createPlan(draft());
    now = DateTime(2026, 1, 31);
    await plans.generateDue();
    await manual(333);
    expect(
      (await movements.getSnapshot()).accounts.first.currentBalance.minorUnits,
      666,
    );
    final snapshot = await plans.reconcile(1, 1, 2, 'Referencia sintética');
    expect(snapshot.movements, hasLength(2));
    expect(snapshot.accounts.first.currentBalance.minorUnits, 333);
    expect(snapshot.movements.first.details.reconciledIntoId, 1);
    expect(snapshot.movements.last.details.reconciled, isTrue);
    expect(
      MonthlySummary.calculate(
        snapshot,
        2026,
        1,
      ).currencies.single.expense.minorUnits,
      333,
    );
    expect(
      (await plans.reconcile(
        1,
        1,
        2,
        'Referencia sintética',
      )).accounts.first.currentBalance.minorUnits,
      333,
    );
  });
  test(
    'Rechaza conciliación ambigua/incompatible sin modificar la deuda',
    () async {
      await seed();
      await plans.createPlan(draft());
      now = DateTime(2026, 1, 31);
      await plans.generateDue();
      await manual(334);
      await expectLater(
        plans.reconcile(1, 1, 2, 'Referencia sintética'),
        throwsA(isA<InstallmentValidationException>()),
      );
      expect(
        (await movements.getSnapshot())
            .accounts
            .first
            .currentBalance
            .minorUnits,
        667,
      );
      expect(
        await (await database.database).query('installment_reconciliations'),
        isEmpty,
      );
    },
  );
  test('Editar pendiente conserva condiciones originales e histórico y ajusta última cuota futura', () async {
    await seed();
    await plans.createPlan(draft());
    now = DateTime(2026, 1, 31);
    await plans.generateDue();
    final db = await database.database;
    final old = await db.query('movements');
    final snapshot = await plans.reviseFuture(
      1,
      description: 'Descripción ajustada',
      categoryId: null,
      monthly: Money(500, Currency.gtq),
      nextDate: DateTime(2026, 2, 28),
      chargeDay: 28,
    );
    expect(await db.query('movements'), old);
    expect(
      snapshot.installmentPlans.single.schedule.map((i) => i.amount.minorUnits),
      [333, 500, 167],
    );
    expect(
      snapshot.installmentPlans.single.originalDescription,
      'Compra sintética',
    );
    expect(
      snapshot.installmentPlans.single.draft.monthlyAmount.minorUnits,
      333,
    );
    expect(await db.query('installment_revisions'), hasLength(1));
  });
  test(
    'Fallo de persistencia revierte toda la recuperación y permite reintentar',
    () async {
      await seed();
      await plans.createPlan(draft());
      final db = await database.database;
      await db.execute(
        "CREATE TRIGGER reject_second BEFORE INSERT ON movements WHEN NEW.origin = 'installmentCharge' AND NEW.installment_number = 2 BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END",
      );
      now = DateTime(2026, 3, 31);
      await expectLater(plans.generateDue(), throwsA(isA<DatabaseException>()));
      expect(await db.query('movements'), isEmpty);
      expect(
        (await db.query('installments')).every((r) => r['movement_id'] == null),
        isTrue,
      );
      await db.execute('DROP TRIGGER reject_second');
      expect((await plans.generateDue()).movements, hasLength(3));
    },
  );
}
