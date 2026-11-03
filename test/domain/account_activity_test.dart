import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/account_activity.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';

void main() {
  Movement row(
    int id,
    DateTime date, {
    int account = 1,
    int? other,
    int? debit,
    int? original,
    MovementType type = MovementType.expense,
  }) => Movement(
    id: id,
    details: MovementDetails(
      type: type,
      accountId: account,
      counterpartyAccountId: other,
      debitCardId: debit,
      originalMovementId: original,
      amount: Money(100, Currency.gtq),
      date: date,
      description: 'Operación sintética',
    ),
  );
  test('Períodos incluyen mes completo y contrapartes sin incluir el mes siguiente', () {
    final rows = [
      row(1, DateTime(2025, 12, 31)),
      row(2, DateTime(2026, 1, 1)),
      row(3, DateTime(2026, 1, 31)),
      row(4, DateTime(2026, 2, 1)),
      row(
        5,
        DateTime(2026, 1, 15),
        account: 2,
        other: 1,
        type: MovementType.transfer,
      ),
      row(6, DateTime(2026, 1, 15), account: 3),
    ];
    final activity = AccountActivity(accountId: 1, movements: rows);
    expect(activity.inMonth(DateTime(2026, 1)).map((m) => m.id), [2, 3, 5]);
    expect(activity.inMonth(DateTime(2025, 12)).single.id, 1);
    expect(activity.inMonth(DateTime(2026, 2)).single.id, 4);
  });
  test('Débito identificado incluye su devolución de compra de otro mes y excluye otras tarjetas', () {
    final rows = [
      row(1, DateTime(2025, 12, 20), debit: 7),
      row(2, DateTime(2026, 1, 2), debit: 8),
      row(3, DateTime(2026, 1, 2)),
      row(4, DateTime(2026, 1, 3), type: MovementType.refund, original: 1),
      row(5, DateTime(2026, 1, 4), debit: 7),
    ];
    final activity = AccountActivity(
      accountId: 1,
      debitCardId: 7,
      movements: rows,
    );
    expect(activity.identifiesDebitCards, isTrue);
    expect(activity.inMonth(DateTime(2026, 1)).map((m) => m.id), [4, 5]);
    expect(
      AccountActivity(
        accountId: 1,
        debitCardId: 9,
        movements: rows,
      ).inMonth(DateTime(2026, 1)),
      isEmpty,
    );
  });
  test('Sin identificación por tarjeta presenta alcance bancario sin inventar vínculos', () {
    final activity = AccountActivity(
      accountId: 1,
      debitCardId: 7,
      movements: [
        row(1, DateTime(2026, 1, 1)),
        row(2, DateTime(2026, 1, 1), account: 2),
      ],
    );
    expect(activity.identifiesDebitCards, isFalse);
    expect(activity.inMonth(DateTime(2026, 1)).single.id, 1);
  });
  test('Disponible se calcula únicamente con límite y deuda no negativa de la misma moneda', () {
    final details = AccountDetails(
      name: 'Crédito sintético',
      type: AccountType.creditCard,
      openingBalance: Money(700, Currency.gtq),
      creditLimit: Money(1000, Currency.gtq),
      secondaryOpeningBalance: Money(500, Currency.usd),
      openingDate: DateTime(2025, 12, 1),
    );
    final account = Account(id: 1, details: details);
    expect(account.availableCreditFor(Currency.gtq), Money(300, Currency.gtq));
    expect(account.availableCreditFor(Currency.usd), isNull);
    expect(
      Account(
        id: 1,
        details: details,
        currentBalance: Money(1200, Currency.gtq),
      ).availableCreditFor(Currency.gtq)!.minorUnits,
      0,
    );
    expect(
      Account(
        id: 1,
        details: details,
        currentBalance: Money(-100, Currency.gtq),
      ).availableCreditFor(Currency.gtq),
      isNull,
    );
  });
  test('Corte y pago son opcionales, completos e independientes y no se aplican a bancos', () {
    AccountDetails details({
      AccountType type = AccountType.creditCard,
      DateTime? cut,
      DateTime? due,
    }) => AccountDetails(
      name: 'Cuenta sintética',
      type: type,
      openingBalance: Money(0, Currency.gtq),
      openingDate: DateTime(2025, 12, 1),
      nextClosingDate: cut,
      nextPaymentDueDate: due,
    );
    expect(details().nextClosingDate, isNull);
    final configured = details(
      cut: DateTime(2026, 11, 20, 12),
      due: DateTime(2026, 11, 5, 23),
    );
    expect(configured.nextClosingDate, DateTime(2026, 11, 20));
    expect(configured.nextPaymentDueDate, DateTime(2026, 11, 5));
    expect(
      () => details(type: AccountType.bank, cut: DateTime(2026, 11, 20)),
      throwsArgumentError,
    );
    expect(() => details(cut: DateTime(10000)), throwsArgumentError);
  });
}
