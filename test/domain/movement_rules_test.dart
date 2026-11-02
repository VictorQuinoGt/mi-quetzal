import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/rules/movement_rules.dart';

Account sampleAccount(
  int id,
  AccountType type,
  int opening, {
  Currency currency = Currency.gtq,
}) => Account(
  id: id,
  details: AccountDetails(
    name: 'Cuenta sintética $id',
    type: type,
    openingBalance: Money(opening, currency),
    openingDate: DateTime(2026, 10, 1),
  ),
);

Movement sampleMovement(
  int id,
  MovementType type,
  int accountId,
  int amount, {
  int? other,
  Currency currency = Currency.gtq,
  DateTime? date,
}) => Movement(
  id: id,
  details: MovementDetails(
    type: type,
    accountId: accountId,
    counterpartyAccountId: other,
    amount: Money(amount, currency),
    description: 'Operación sintética',
    date: date ?? DateTime(2026, 11, 2),
  ),
);

void main() {
  final accounts = [
    sampleAccount(1, AccountType.bank, 100000),
    sampleAccount(2, AccountType.cash, 10000),
    sampleAccount(3, AccountType.creditCard, 5000),
  ];
  int balance(LedgerSnapshot ledger, int id) =>
      ledger.accounts.firstWhere((a) => a.id == id).currentBalance.minorUnits;

  test('Compras con fondos reducen saldo y con crédito aumentan deuda', () {
    final ledger = LedgerSnapshot.calculate(accounts, [
      sampleMovement(1, MovementType.expense, 1, 1000),
      sampleMovement(2, MovementType.expense, 2, 2000),
      sampleMovement(3, MovementType.expense, 3, 3000),
    ]);
    expect(balance(ledger, 1), 99000);
    expect(balance(ledger, 2), 8000);
    expect(balance(ledger, 3), 8000);
    expect(ledger.movements.where((m) => m.details.isExpense), hasLength(3));
    expect(accounts.first.currentBalance.minorUnits, 100000);
  });

  test('Un pago reduce origen y deuda sin generar ingreso o segundo gasto', () {
    final ledger = LedgerSnapshot.calculate(accounts, [
      sampleMovement(1, MovementType.creditPayment, 1, 3000, other: 3),
    ]);
    expect(balance(ledger, 1), 97000);
    expect(balance(ledger, 3), 2000);
    expect(ledger.movements.single.details.isExpense, isFalse);
    expect(ledger.movements.single.details.isIncome, isFalse);
  });

  test(
    'Transferencias conservan fondos y permiten un retiro banco-efectivo',
    () {
      final ledger = LedgerSnapshot.calculate(accounts, [
        sampleMovement(1, MovementType.transfer, 1, 3000, other: 2),
      ]);
      expect(balance(ledger, 1), 97000);
      expect(balance(ledger, 2), 13000);
      expect(balance(ledger, 1) + balance(ledger, 2), 110000);
      expect(ledger.movements.single.details.isExpense, isFalse);
    },
  );

  test('Un ingreso aumenta fondos y no puede aplicarse a crédito', () {
    final ledger = LedgerSnapshot.calculate(accounts, [
      sampleMovement(1, MovementType.income, 2, 101),
    ]);
    expect(balance(ledger, 2), 10101);
    expect(ledger.movements.single.details.isIncome, isTrue);
    expect(
      () => LedgerSnapshot.calculate(accounts, [
        sampleMovement(1, MovementType.income, 3, 100),
      ]),
      throwsA(isA<MovementValidationException>()),
    );
  });

  test(
    'Rechaza monedas distintas, tipos incompatibles y referencias inexistentes',
    () {
      final usd = sampleAccount(
        4,
        AccountType.bank,
        100,
        currency: Currency.usd,
      );
      for (final movement in [
        sampleMovement(1, MovementType.transfer, 1, 100, other: 4),
        sampleMovement(1, MovementType.transfer, 3, 100, other: 2),
        sampleMovement(1, MovementType.transfer, 1, 100, other: 3),
        sampleMovement(1, MovementType.creditPayment, 1, 100, other: 2),
        sampleMovement(1, MovementType.expense, 99, 100),
        sampleMovement(1, MovementType.expense, 1, 100, currency: Currency.usd),
      ]) {
        expect(
          () => LedgerSnapshot.calculate([...accounts, usd], [movement]),
          throwsA(isA<MovementValidationException>()),
        );
      }
    },
  );

  test('Valida importes positivos, descripción y cuentas diferentes', () {
    expect(
      () => sampleMovement(1, MovementType.expense, 1, 0),
      throwsA(isA<MovementValidationException>()),
    );
    expect(
      () => sampleMovement(1, MovementType.expense, 1, -1),
      throwsA(isA<MovementValidationException>()),
    );
    expect(
      () => sampleMovement(1, MovementType.transfer, 1, 1, other: 1),
      throwsA(isA<MovementValidationException>()),
    );
    expect(
      () => sampleMovement(1, MovementType.transfer, 1, 1),
      throwsA(isA<MovementValidationException>()),
    );
    expect(
      () => MovementDetails(
        type: MovementType.expense,
        accountId: 1,
        amount: Money(1, Currency.gtq),
        date: DateTime(2026, 11, 2),
        description: ' ',
      ),
      throwsA(isA<MovementValidationException>()),
    );
  });

  test(
    'No permite operaciones anteriores a la apertura ni futuras al registrar',
    () {
      final old = sampleMovement(
        1,
        MovementType.expense,
        1,
        1,
        date: DateTime(2026, 9, 30),
      );
      expect(
        () => LedgerSnapshot.calculate(accounts, [old]),
        throwsA(isA<MovementValidationException>()),
      );
      final future = sampleMovement(
        1,
        MovementType.expense,
        1,
        1,
        date: DateTime(2026, 11, 3),
      );
      expect(
        () => MovementRules.validateRegistration(
          future.details,
          accounts,
          DateTime(2026, 11, 2),
        ),
        throwsA(isA<MovementValidationException>()),
      );
    },
  );

  test('Valida efectivo cronológicamente incluso al insertar movimientos retroactivos', () {
    final cash = [sampleAccount(1, AccountType.cash, 100)];
    final income = sampleMovement(1, MovementType.income, 1, 200);
    final expense = sampleMovement(
      2,
      MovementType.expense,
      1,
      150,
      date: DateTime(2026, 11, 1),
    );
    expect(
      () => LedgerSnapshot.calculate(cash, [income, expense]),
      throwsA(isA<MovementValidationException>()),
    );
    final bank = [sampleAccount(1, AccountType.bank, 0)];
    expect(balance(LedgerSnapshot.calculate(bank, [expense]), 1), -150);
  });

  test('Un pago mayor a la deuda conserva el saldo a favor', () {
    final ledger = LedgerSnapshot.calculate(accounts, [
      sampleMovement(1, MovementType.creditPayment, 1, 6000, other: 3),
    ]);
    final credit = ledger.accounts.last;
    expect(credit.currentBalance.minorUnits, -1000);
    expect(credit.hasCreditInFavor, isTrue);
    expect(credit.displayBalance, Money(1000, Currency.gtq));
  });

  test(
    'Conserva compras idénticas y ordena fecha e identidad sin mutar los datos',
    () {
      final entries = [
        sampleMovement(1, MovementType.expense, 1, 101),
        sampleMovement(2, MovementType.expense, 1, 101),
      ];
      final ledger = LedgerSnapshot.calculate(accounts, entries);
      expect(balance(ledger, 1), 99798);
      expect(ledger.movements.map((m) => m.id), [2, 1]);
      expect(entries.map((m) => m.id), [1, 2]);
      expect(() => ledger.movements.clear(), throwsUnsupportedError);
    },
  );

  test('Rechaza desbordamientos exactos del saldo en vez de redondear', () {
    final huge = [sampleAccount(1, AccountType.bank, 9007199254740991)];
    expect(
      () => LedgerSnapshot.calculate(huge, [
        sampleMovement(1, MovementType.income, 1, 1),
      ]),
      throwsA(isA<MovementValidationException>()),
    );
    expect(
      () => Money(1, Currency.gtq).add(Money(1, Currency.usd)),
      throwsArgumentError,
    );
    expect(
      Money(29, Currency.gtq).add(Money(1, Currency.gtq)),
      Money(30, Currency.gtq),
    );
  });
}
