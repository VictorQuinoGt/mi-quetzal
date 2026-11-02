import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/monthly_summary.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/models/movement_filter.dart';

void main() {
  Account account(int id, AccountType type, Currency currency) => Account(
    id: id,
    details: AccountDetails(
      name: 'Cuenta sintética',
      type: type,
      openingBalance: Money(
        type == AccountType.creditCard ? 0 : 10000,
        currency,
      ),
      openingDate: DateTime(2026, 10, 1),
    ),
  );
  final accounts = [
    account(1, AccountType.bank, Currency.gtq),
    account(2, AccountType.cash, Currency.gtq),
    account(3, AccountType.creditCard, Currency.gtq),
    account(4, AccountType.bank, Currency.usd),
  ];
  final categories = [
    Category(
      id: 1,
      details: CategoryDetails(
        name: 'Alimentos sintéticos',
        kind: CategoryKind.expense,
      ),
    ),
    Category(
      id: 2,
      details: CategoryDetails(
        name: 'Ingreso sintético',
        kind: CategoryKind.income,
      ),
    ),
  ];
  final cards = [
    DebitCard(
      id: 1,
      details: DebitCardDetails(name: 'Débito sintético', accountId: 1),
    ),
  ];
  Movement item(
    int id,
    MovementType type,
    int source,
    int amount, {
    Currency currency = Currency.gtq,
    int? other,
    int? category,
    int? debit,
    DateTime? date,
  }) => Movement(
    id: id,
    details: MovementDetails(
      type: type,
      accountId: source,
      counterpartyAccountId: other,
      categoryId: category,
      debitCardId: debit,
      amount: Money(amount, currency),
      date: date ?? DateTime(2026, 11, 2),
      description: 'Operación sintética',
    ),
  );
  final entries = [
    item(1, MovementType.expense, 1, 200, date: DateTime(2026, 10, 31)),
    item(2, MovementType.income, 1, 10000, category: 2),
    item(3, MovementType.expense, 2, 100),
    item(4, MovementType.expense, 3, 500, category: 1),
    item(5, MovementType.expense, 1, 125, category: 1, debit: 1),
    item(6, MovementType.creditPayment, 1, 200, other: 3),
    item(7, MovementType.transfer, 1, 300, other: 2),
    item(8, MovementType.income, 4, 500, currency: Currency.usd),
    item(9, MovementType.expense, 4, 200, currency: Currency.usd),
  ];
  LedgerSnapshot ledger() => LedgerSnapshot.calculate(
    accounts,
    entries,
    categories: categories,
    debitCards: cards,
  );

  test(
    'Categorías validan nombre y compatibilidad sin clasificar por descripción',
    () {
      expect(
        CategoryDetails(name: '  Prueba  ', kind: CategoryKind.expense).name,
        'Prueba',
      );
      expect(
        () => CategoryDetails(name: ' ', kind: CategoryKind.expense),
        throwsA(isA<CategoryValidationException>()),
      );
      expect(
        () => CategoryDetails(name: 'a' * 61, kind: CategoryKind.income),
        throwsA(isA<CategoryValidationException>()),
      );
      expect(categories.first.details.supports(MovementType.expense), isTrue);
      expect(
        categories.first.details.supports(MovementType.creditPayment),
        isFalse,
      );
      expect(categories.last.details.supports(MovementType.income), isTrue);
      expect(entries.first.details.categoryId, isNull);
    },
  );

  test(
    'Rechaza categorías inexistentes, incompatibles y asignadas a pagos',
    () {
      for (final invalid in [
        item(1, MovementType.expense, 1, 100, category: 2),
        item(1, MovementType.income, 1, 100, category: 1),
        item(1, MovementType.expense, 1, 100, category: 99),
      ]) {
        expect(
          () => LedgerSnapshot.calculate(accounts, [
            invalid,
          ], categories: categories),
          throwsA(isA<MovementValidationException>()),
        );
      }
      expect(
        () =>
            item(1, MovementType.creditPayment, 1, 100, other: 3, category: 1),
        throwsA(isA<MovementValidationException>()),
      );
    },
  );

  test(
    'Cambiar categoría conserva todos los datos financieros del movimiento',
    () {
      final original = entries[4].details;
      final changed = original.withCategory(null);
      expect(changed.categoryId, isNull);
      expect(changed.amount, original.amount);
      expect(changed.date, original.date);
      expect(changed.description, original.description);
      expect(changed.accountId, original.accountId);
      expect(changed.debitCardId, original.debitCardId);
    },
  );

  test(
    'Resumen separa monedas y excluye aperturas, transferencias y pagos',
    () {
      final summary = MonthlySummary.calculate(ledger(), 2026, 11);
      final gtq = summary.currencies.first;
      final usd = summary.currencies.last;
      expect(gtq.currency, Currency.gtq);
      expect(gtq.income, Money(10000, Currency.gtq));
      expect(gtq.expense, Money(725, Currency.gtq));
      expect(gtq.difference, Money(9275, Currency.gtq));
      expect(usd.income, Money(500, Currency.usd));
      expect(usd.expense, Money(200, Currency.usd));
      expect(usd.difference, Money(300, Currency.usd));
      expect(() => summary.currencies.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Agrupa compras con crédito y débito una vez y conserva sin categoría',
    () {
      final summary = MonthlySummary.calculate(
        ledger(),
        2026,
        11,
      ).currencies.first;
      expect(summary.expenseByCategory.map((g) => g.amount.minorUnits), [
        625,
        100,
      ]);
      expect(summary.expenseByCategory.first.name, 'Alimentos sintéticos');
      expect(summary.expenseByCategory.last.categoryId, isNull);
      expect(summary.expenseByCategory.last.name, 'Sin categoría');
      expect(summary.incomeByCategory.single.amount.minorUnits, 10000);
      expect(() => summary.expenseByCategory.clear(), throwsUnsupportedError);
    },
  );

  test('Meses distintos y meses con solo transferencias no inventan ingresos/gastos', () {
    expect(
      MonthlySummary.calculate(
        ledger(),
        2026,
        10,
      ).currencies.single.expense.minorUnits,
      200,
    );
    expect(MonthlySummary.calculate(ledger(), 2026, 12).currencies, isEmpty);
    final transfers = LedgerSnapshot.calculate(accounts, [
      item(1, MovementType.transfer, 1, 100, other: 2),
    ]);
    expect(MonthlySummary.calculate(transfers, 2026, 11).currencies, isEmpty);
    expect(
      () => MonthlySummary.calculate(ledger(), 2026, 13),
      throwsArgumentError,
    );
  });

  test('Distingue categorías de nombre idéntico por identidad', () {
    final repeated = Category(
      id: 3,
      details: CategoryDetails(
        name: categories.first.details.name,
        kind: CategoryKind.expense,
      ),
    );
    final data = LedgerSnapshot.calculate(
      accounts,
      [
        item(1, MovementType.expense, 1, 100, category: 1),
        item(2, MovementType.expense, 1, 100, category: 3),
      ],
      categories: [...categories, repeated],
    );
    expect(
      MonthlySummary.calculate(
        data,
        2026,
        11,
      ).currencies.single.expenseByCategory.map((g) => g.categoryId),
      [1, 3],
    );
  });

  test(
    'Filtra categoría y sin categoría excluyendo transferencias y pagos',
    () {
      expect(MovementFilter(categoryId: 1).apply(entries).map((m) => m.id), [
        4,
        5,
      ]);
      expect(
        MovementFilter(uncategorizedOnly: true).apply(entries).map((m) => m.id),
        [1, 3, 8, 9],
      );
      expect(
        () => MovementFilter(categoryId: 1, uncategorizedOnly: true),
        throwsArgumentError,
      );
      expect(
        MonthlySummary.calculate(
          ledger(),
          2026,
          11,
        ).currencies.first.expense.minorUnits,
        725,
      );
    },
  );

  test(
    'Totales fuera de rango fallan explícitamente sin redondear en JS o Dart',
    () {
      final data = LedgerSnapshot.calculate(
        [...accounts, account(5, AccountType.bank, Currency.gtq)],
        [
          item(1, MovementType.expense, 1, 9007199254740991),
          item(2, MovementType.expense, 5, 10001),
        ],
      );
      expect(
        () => MonthlySummary.calculate(data, 2026, 11),
        throwsArgumentError,
      );
      expect(
        () => Money.fromBigInt(
          BigInt.parse('99999999999999999999999999999'),
          Currency.gtq,
        ),
        throwsArgumentError,
      );
    },
  );
}
