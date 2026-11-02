import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/monthly_summary.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/rules/account_rules.dart';

void main() {
  AccountDetails credit({Money? secondary, Money? limit}) => AccountDetails(
    name: 'Crédito sintético',
    type: AccountType.creditCard,
    openingBalance: Money(1000, Currency.gtq),
    secondaryOpeningBalance: secondary,
    secondaryCreditLimit: limit,
    openingDate: DateTime(2026, 10, 1),
  );
  Movement movement(
    int id,
    MovementType type,
    int account,
    int amount,
    Currency currency, {
    int? other,
    int? original,
  }) => Movement(
    id: id,
    details: MovementDetails(
      type: type,
      accountId: account,
      counterpartyAccountId: other,
      originalMovementId: original,
      amount: Money(amount, currency),
      date: DateTime(2026, 11, 1),
      description: 'Operación sintética',
    ),
  );

  test('Compras, pagos y devoluciones afectan únicamente la moneda de cada operación', () {
    final card = Account(
      id: 1,
      details: credit(secondary: Money(2000, Currency.usd)),
    );
    final banks = [
      for (final entry in [(2, Currency.gtq), (3, Currency.usd)])
        Account(
          id: entry.$1,
          details: AccountDetails(
            name: 'Banco sintético',
            type: AccountType.bank,
            openingBalance: Money(10000, entry.$2),
            openingDate: DateTime(2026, 10, 1),
          ),
        ),
    ];
    final snapshot = LedgerSnapshot.calculate(
      [card, ...banks],
      [
        movement(1, MovementType.expense, 1, 100, Currency.gtq),
        movement(2, MovementType.expense, 1, 200, Currency.usd),
        movement(3, MovementType.creditPayment, 3, 300, Currency.usd, other: 1),
        movement(4, MovementType.refund, 1, 50, Currency.usd, original: 2),
      ],
    );
    expect(snapshot.accounts.first.currentBalance, Money(1100, Currency.gtq));
    expect(
      snapshot.accounts.first.balanceFor(Currency.usd),
      Money(1850, Currency.usd),
    );
    expect(snapshot.accounts[1].currentBalance.minorUnits, 10000);
    expect(snapshot.accounts[2].currentBalance.minorUnits, 9700);
    expect(
      snapshot.accounts.first.details.secondaryOpeningBalance!.minorUnits,
      2000,
    );
    final report = MonthlySummary.calculate(snapshot, 2026, 11);
    expect(report.currencies.map((r) => r.expense.minorUnits), [100, 150]);
    expect(report.currencies.map((r) => r.income.minorUnits), [0, 0]);
  });
  test('Saldo a favor en USD no cambia la deuda GTQ', () {
    final card = Account(
      id: 1,
      details: credit(secondary: Money(0, Currency.usd)),
    );
    final bank = Account(
      id: 2,
      details: AccountDetails(
        name: 'USD sintético',
        type: AccountType.bank,
        openingBalance: Money(1000, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    final snapshot = LedgerSnapshot.calculate(
      [card, bank],
      [movement(1, MovementType.creditPayment, 2, 500, Currency.usd, other: 1)],
    );
    expect(snapshot.accounts.first.balanceFor(Currency.usd)!.minorUnits, -500);
    expect(snapshot.accounts.first.currentBalance.minorUnits, 1000);
  });
  test('Rechaza segunda moneda repetida, negativa, límite incompatible y moneda no registrada', () {
    for (final value in [Money(0, Currency.gtq), Money(-1, Currency.usd)]) {
      expect(() => credit(secondary: value), throwsArgumentError);
    }
    expect(() => credit(limit: Money(0, Currency.usd)), throwsArgumentError);
    expect(
      () => credit(
        secondary: Money(0, Currency.usd),
        limit: Money(1, Currency.gtq),
      ),
      throwsArgumentError,
    );
    expect(
      () => LedgerSnapshot.calculate(
        [Account(id: 1, details: credit())],
        [movement(1, MovementType.expense, 1, 100, Currency.usd)],
      ),
      throwsA(isA<MovementValidationException>()),
    );
    expect(
      () => AccountDetails(
        name: 'Banco sintético',
        type: AccountType.bank,
        openingBalance: Money(0, Currency.gtq),
        secondaryOpeningBalance: Money(0, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
      throwsArgumentError,
    );
  });
  test(
    'Edición conserva tipo, moneda principal y toda moneda con historial',
    () {
      final card = Account(
        id: 1,
        details: credit(secondary: Money(0, Currency.usd)),
      );
      expect(
        () => AccountRules.validateUpdate(
          card,
          credit(),
          movements: [movement(1, MovementType.expense, 1, 100, Currency.usd)],
        ),
        throwsArgumentError,
      );
      for (final other in [
        AccountDetails(
          name: 'Banco sintético',
          type: AccountType.bank,
          openingBalance: Money(1000, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
        ),
        AccountDetails(
          name: 'Crédito sintético',
          type: AccountType.creditCard,
          openingBalance: Money(1000, Currency.usd),
          openingDate: DateTime(2026, 10, 1),
        ),
      ]) {
        expect(
          () => AccountRules.validateUpdate(card, other),
          throwsArgumentError,
        );
      }
    },
  );
  test('Tipo bancario solo pertenece a bancos; apertura para editar conserva centavos exactos', () {
    expect(
      () => AccountDetails(
        name: 'Crédito sintético',
        type: AccountType.creditCard,
        bankAccountType: BankAccountType.savings,
        openingBalance: Money(0, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
      throwsArgumentError,
    );
    for (final cents in [-1, 0, 29, 9007199254740991]) {
      final money = Money(cents, Currency.gtq);
      expect(Money.parse(money.input, Currency.gtq), money);
    }
  });
}
