import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/monthly_summary.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/rules/movement_rules.dart';

void main() {
  final accounts = [
    for (final entry in [
      (1, AccountType.creditCard),
      (2, AccountType.cash),
      (3, AccountType.bank),
    ])
      Account(
        id: entry.$1,
        details: AccountDetails(
          name: 'Cuenta sintética ${entry.$1}',
          type: entry.$2,
          openingBalance: Money(10000, Currency.gtq),
          secondaryOpeningBalance: entry.$2 == AccountType.creditCard
              ? Money(3000, Currency.usd)
              : null,
          openingDate: DateTime(2026, 11, 15),
        ),
      ),
  ];
  final categories = [
    for (final kind in CategoryKind.values)
      Category(
        id: kind.index + 1,
        details: CategoryDetails(name: 'Categoría sintética', kind: kind),
      ),
  ];
  MovementDetails payment({
    int account = 1,
    PaymentFunding funding = PaymentFunding.externalCash,
    Currency currency = Currency.gtq,
    int amount = 1250,
    int? category = 3,
    int? other,
    MovementType type = MovementType.creditPayment,
  }) => MovementDetails(
    type: type,
    accountId: account,
    counterpartyAccountId: other,
    paymentFunding: funding,
    categoryId: category,
    amount: Money(amount, currency),
    date: DateTime(2026, 10, 1),
    description: 'Pago sintético',
  );
  LedgerSnapshot ledger(MovementDetails details) => LedgerSnapshot.calculate(
    accounts,
    [Movement(id: 1, details: details)],
    categories: categories,
  );

  test('Pago en agencia reduce solo la deuda y conserva separados GTQ/USD y los reportes', () {
    for (final currency in Currency.values) {
      final details = payment(currency: currency);
      MovementRules.validateRegistration(
        details,
        accounts,
        DateTime(2026, 11, 15),
        categories: categories,
      );
      final snapshot = ledger(details);
      expect(
        snapshot.accounts.first.balanceFor(currency)!.minorUnits,
        currency == Currency.gtq ? 8750 : 1750,
      );
      expect(
        snapshot.accounts.first
            .balanceFor(currency == Currency.gtq ? Currency.usd : Currency.gtq)!
            .minorUnits,
        currency == Currency.gtq ? 3000 : 10000,
      );
      expect(
        snapshot.accounts.skip(1).map((a) => a.currentBalance.minorUnits),
        [10000, 10000],
      );
      expect(MonthlySummary.calculate(snapshot, 2026, 10).currencies, isEmpty);
      expect(
        details.withCategory(null).paymentFunding,
        PaymentFunding.externalCash,
      );
      expect(
        ledger(details.withCategory(null)).accounts.first.currentBalance,
        snapshot.accounts.first.currentBalance,
      );
    }
  });

  test(
    'El pago desde efectivo registrado descuenta fondos y deuda una sola vez',
    () {
      final snapshot = ledger(
        payment(account: 2, funding: PaymentFunding.account, other: 1),
      );
      expect(snapshot.accounts.map((a) => a.currentBalance.minorUnits), [
        8750,
        8750,
        10000,
      ]);
      expect(
        () => ledger(
          payment(
            account: 2,
            funding: PaymentFunding.account,
            other: 1,
            amount: 10001,
          ),
        ),
        throwsA(isA<MovementValidationException>()),
      );
    },
  );

  test('Agencia exige tarjeta y categoría Pago; rechaza contrapartes y otras operaciones', () {
    expect(
      categories.last.details.supports(MovementType.creditPayment),
      isTrue,
    );
    for (final type in MovementType.values.where(
      (t) => t != MovementType.creditPayment,
    )) {
      expect(categories.last.details.supports(type), isFalse);
      expect(
        () => payment(type: type),
        throwsA(isA<MovementValidationException>()),
      );
    }
    for (final id in [2, 3, 99]) {
      expect(
        () => ledger(payment(account: id)),
        throwsA(isA<MovementValidationException>()),
      );
    }
    for (final id in [1, 2, 99]) {
      expect(
        () => ledger(payment(category: id)),
        throwsA(isA<MovementValidationException>()),
      );
    }
    expect(
      () => payment(other: 2),
      throwsA(isA<MovementValidationException>()),
    );
    final gtqOnly = Account(
      id: 1,
      details: AccountDetails(
        name: 'Tarjeta GTQ sintética',
        type: AccountType.creditCard,
        openingBalance: Money(0, Currency.gtq),
        openingDate: DateTime(2026),
      ),
    );
    expect(
      () => MovementRules.effects(payment(currency: Currency.usd), [
        gtqOnly,
      ], categories: categories),
      throwsA(isA<MovementValidationException>()),
    );
  });
}
