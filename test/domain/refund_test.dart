import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/monthly_summary.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/models/movement_filter.dart';
import 'package:mi_quetzal/domain/rules/movement_rules.dart';

void main() {
  final categories = [
    Category(
      id: 1,
      details: CategoryDetails(
        name: 'Compra sintética',
        kind: CategoryKind.expense,
      ),
    ),
    Category(
      id: 2,
      details: CategoryDetails(
        name: 'Otra sintética',
        kind: CategoryKind.expense,
      ),
    ),
  ];
  Account account(AccountType type) => Account(
    id: 1,
    details: AccountDetails(
      name: 'Cuenta sintética',
      type: type,
      openingBalance: Money(
        type == AccountType.creditCard ? 0 : 1000,
        Currency.gtq,
      ),
      openingDate: DateTime(2026, 10, 1),
    ),
  );
  Movement purchase({int? categoryId = 1}) => Movement(
    id: 1,
    details: MovementDetails(
      type: MovementType.expense,
      accountId: 1,
      amount: Money(500, Currency.gtq),
      categoryId: categoryId,
      date: DateTime(2026, 10, 31),
      description: 'Compra sintética',
    ),
  );
  Movement refund(
    int id,
    int amount, {
    int originalId = 1,
    int accountId = 1,
    Currency currency = Currency.gtq,
    DateTime? date,
  }) => Movement(
    id: id,
    details: MovementDetails(
      type: MovementType.refund,
      accountId: accountId,
      originalMovementId: originalId,
      amount: Money(amount, currency),
      date: date ?? DateTime(2026, 11, 1),
      description: 'Devolución sintética',
    ),
  );
  LedgerSnapshot ledger(
    List<Movement> movements, {
    AccountType type = AccountType.bank,
  }) => LedgerSnapshot.calculate(
    [account(type)],
    movements,
    categories: categories,
  );

  for (final type in AccountType.values) {
    test(
      'Devolución parcial y total en ${type.name} revierte saldo sin ingreso',
      () {
        final original = purchase();
        final partial = ledger([original, refund(2, 125)], type: type);
        expect(
          partial.accounts.single.currentBalance.minorUnits,
          type == AccountType.creditCard ? 375 : 625,
        );
        expect(
          MovementRules.remainingRefund(original, partial.movements).minorUnits,
          375,
        );
        final complete = ledger([
          original,
          refund(2, 125),
          refund(3, 375),
        ], type: type);
        expect(
          complete.accounts.single.currentBalance.minorUnits,
          type == AccountType.creditCard ? 0 : 1000,
        );
        expect(
          MovementRules.remainingRefund(
            original,
            complete.movements,
          ).minorUnits,
          0,
        );
        final summary = MonthlySummary.calculate(
          complete,
          2026,
          11,
        ).currencies.single;
        expect(summary.income.minorUnits, 0);
        expect(summary.expense.minorUnits, -500);
      },
    );
  }
  test('Crédito pagado conserva saldo a favor tras devolución', () {
    final cash = Account(
      id: 2,
      details: AccountDetails(
        name: 'Banco sintético',
        type: AccountType.bank,
        openingBalance: Money(1000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    final payment = Movement(
      id: 2,
      details: MovementDetails(
        type: MovementType.creditPayment,
        accountId: 2,
        counterpartyAccountId: 1,
        amount: Money(500, Currency.gtq),
        date: DateTime(2026, 11, 1),
        description: 'Pago sintético',
      ),
    );
    final snapshot = LedgerSnapshot.calculate(
      [account(AccountType.creditCard), cash],
      [purchase(), payment, refund(3, 500)],
      categories: categories,
    );
    expect(snapshot.accounts.first.currentBalance.minorUnits, -500);
    expect(snapshot.accounts.first.hasCreditInFavor, isTrue);
    expect(snapshot.accounts.last.currentBalance.minorUnits, 500);
  });
  test('Rechaza exceso acumulado aun con devoluciones retroactivas', () {
    expect(
      () => ledger([purchase(), refund(2, 300), refund(3, 201)]),
      throwsA(isA<MovementValidationException>()),
    );
    MovementRules.validateRegistration(
      refund(3, 200).details,
      [account(AccountType.bank)],
      DateTime(2026, 11, 2),
      categories: categories,
      movements: [purchase(), refund(2, 300)],
    );
    expect(
      () => MovementRules.validateRegistration(
        refund(3, 201).details,
        [account(AccountType.bank)],
        DateTime(2026, 11, 2),
        categories: categories,
        movements: [purchase(), refund(2, 300)],
      ),
      throwsA(isA<MovementValidationException>()),
    );
  });
  test(
    'Rechaza compra ausente, otra cuenta, otra moneda, fecha previa y futura',
    () {
      final original = purchase();
      for (final candidate in [
        refund(2, 100, originalId: 9),
        refund(2, 100, accountId: 2),
        refund(2, 100, currency: Currency.usd),
        refund(2, 100, date: DateTime(2026, 10, 30)),
      ]) {
        expect(
          () => MovementRules.validateRefund(candidate.details, [original]),
          throwsA(isA<MovementValidationException>()),
        );
      }
      expect(
        () => MovementRules.validateRegistration(
          refund(2, 100, date: DateTime(2026, 11, 3)).details,
          [account(AccountType.bank)],
          DateTime(2026, 11, 2),
          categories: categories,
          movements: [original],
        ),
        throwsA(isA<MovementValidationException>()),
      );
    },
  );
  test('No devuelve un ingreso ni otra devolución', () {
    final income = Movement(
      id: 1,
      details: MovementDetails(
        type: MovementType.income,
        accountId: 1,
        amount: Money(500, Currency.gtq),
        date: DateTime(2026, 10, 31),
        description: 'Ingreso sintético',
      ),
    );
    expect(
      () => ledger([income, refund(2, 100)]),
      throwsA(isA<MovementValidationException>()),
    );
    expect(
      () => ledger([purchase(), refund(2, 100), refund(3, 100, originalId: 2)]),
      throwsA(isA<MovementValidationException>()),
    );
  });
  test('Exige vínculo exclusivamente en devoluciones y no acepta metadatos propios', () {
    for (final type in [MovementType.refund, MovementType.expense]) {
      expect(
        () => MovementDetails(
          type: type,
          accountId: 1,
          originalMovementId: type == MovementType.expense ? 1 : null,
          amount: Money(100, Currency.gtq),
          date: DateTime(2026, 11, 1),
          description: 'Sintético',
        ),
        throwsA(isA<MovementValidationException>()),
      );
    }
    for (final field in ['category', 'debit', 'other']) {
      expect(
        () => MovementDetails(
          type: MovementType.refund,
          accountId: 1,
          originalMovementId: 1,
          categoryId: field == 'category' ? 1 : null,
          debitCardId: field == 'debit' ? 1 : null,
          counterpartyAccountId: field == 'other' ? 2 : null,
          amount: Money(100, Currency.gtq),
          date: DateTime(2026, 11, 1),
          description: 'Sintético',
        ),
        throwsA(isA<MovementValidationException>()),
      );
    }
  });
  test(
    'Resumen usa mes de devolución y sigue la categoría actual de la compra',
    () {
      final original = purchase();
      final entries = [original, refund(2, 125)];
      final before = ledger(entries);
      expect(
        MonthlySummary.calculate(
          before,
          2026,
          10,
        ).currencies.single.expense.minorUnits,
        500,
      );
      final november = MonthlySummary.calculate(
        before,
        2026,
        11,
      ).currencies.single;
      expect(november.expense.minorUnits, -125);
      expect(november.difference.minorUnits, 125);
      expect(november.expenseByCategory.single.categoryId, 1);
      final after = ledger([
        Movement(id: 1, details: original.details.withCategory(2)),
        refund(2, 125),
      ]);
      expect(
        after.accounts.single.currentBalance,
        before.accounts.single.currentBalance,
      );
      expect(
        MonthlySummary.calculate(
          after,
          2026,
          11,
        ).currencies.single.expenseByCategory.single.categoryId,
        2,
      );
      expect(
        MovementFilter(categoryId: 2).apply(after.movements).map((m) => m.id),
        [2, 1],
      );
      expect(
        MovementFilter(type: MovementType.refund)
            .apply(after.movements)
            .single
            .id,
        2,
      );
      expect(
        MovementFilter(
          uncategorizedOnly: true,
        ).apply(ledger([purchase(categoryId: null), refund(2, 125)]).movements),
        hasLength(2),
      );
    },
  );
  test(
    'Devolver una compra legítima repetida no consume el pendiente de la otra',
    () {
      final original = purchase();
      final duplicate = Movement(id: 2, details: original.details);
      final snapshot = ledger([original, duplicate, refund(3, 500)]);
      expect(
        MovementRules.remainingRefund(duplicate, snapshot.movements).minorUnits,
        500,
      );
    },
  );
}
