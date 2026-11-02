import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';

Account account(int id, AccountType type) => Account(
  id: id,
  details: AccountDetails(
    name: 'Cuenta sintética',
    type: type,
    openingBalance: Money(1000, Currency.gtq),
    openingDate: DateTime(2026, 10, 1),
  ),
);

void main() {
  final bank = account(1, AccountType.bank);
  final cards = [
    for (final id in [1, 2])
      DebitCard(
        id: id,
        details: DebitCardDetails(
          name: 'Débito sintético $id',
          accountId: 1,
          lastFour: '0042',
        ),
      ),
  ];
  Movement purchase(int id, int debitCardId, {int accountId = 1}) => Movement(
    id: id,
    details: MovementDetails(
      type: MovementType.expense,
      accountId: accountId,
      debitCardId: debitCardId,
      amount: Money(100, Currency.gtq),
      date: DateTime(2026, 11, 1),
      description: 'Compra sintética',
    ),
  );

  test(
    'Normaliza alias y conserva últimos cuatro sin almacenar número completo',
    () {
      final details = DebitCardDetails(
        name: '  Débito sintético  ',
        accountId: 1,
        lastFour: ' 0042 ',
      );
      expect(details.name, 'Débito sintético');
      expect(details.lastFour, '0042');
      expect(
        DebitCardDetails(name: 'Débito sintético', accountId: 1).lastFour,
        isNull,
      );
      for (final digits in ['123', '12345', 'abcd', '1234567812345678']) {
        expect(
          () => DebitCardDetails(
            name: 'Débito sintético',
            accountId: 1,
            lastFour: digits,
          ),
          throwsA(isA<DebitCardValidationException>()),
        );
      }
      expect(
        () => DebitCardDetails(name: ' ', accountId: 1),
        throwsA(isA<DebitCardValidationException>()),
      );
    },
  );

  test('Solo se vincula a una cuenta bancaria existente', () {
    final accounts = [
      bank,
      account(2, AccountType.cash),
      account(3, AccountType.creditCard),
    ];
    cards.first.details.validateAccount(accounts);
    for (final id in [2, 3, 99]) {
      expect(
        () => DebitCardDetails(
          name: 'Débito sintético',
          accountId: id,
        ).validateAccount(accounts),
        throwsA(isA<DebitCardValidationException>()),
      );
    }
  });

  test(
    'Dos tarjetas comparten un único saldo y cada compra descuenta una vez',
    () {
      final ledger = LedgerSnapshot.calculate(
        [bank],
        [purchase(1, 1), purchase(2, 2)],
        debitCards: cards,
      );
      expect(ledger.accounts, hasLength(1));
      expect(ledger.debitCards, hasLength(2));
      expect(ledger.accounts.single.currentBalance, Money(800, Currency.gtq));
      expect(
        ledger.accounts.single.details.openingBalance,
        Money(1000, Currency.gtq),
      );
      expect(ledger.movements.where((m) => m.details.isExpense), hasLength(2));
      expect(() => ledger.debitCards.clear(), throwsUnsupportedError);
    },
  );

  test('Rechaza tarjeta inexistente o de otra cuenta sin alterar saldos', () {
    for (final movement in [purchase(1, 99), purchase(1, 1, accountId: 2)]) {
      expect(
        () => LedgerSnapshot.calculate(
          [bank, account(2, AccountType.bank)],
          [movement],
          debitCards: cards,
        ),
        throwsA(isA<MovementValidationException>()),
      );
    }
    expect(bank.currentBalance.minorUnits, 1000);
  });

  test('No permite asociar débito a ingresos, pagos o transferencias', () {
    for (final type in [
      MovementType.income,
      MovementType.transfer,
      MovementType.creditPayment,
    ]) {
      expect(
        () => MovementDetails(
          type: type,
          accountId: 1,
          counterpartyAccountId: type == MovementType.income ? null : 2,
          debitCardId: 1,
          amount: Money(100, Currency.gtq),
          date: DateTime(2026, 11, 1),
          description: 'Operación sintética',
        ),
        throwsA(isA<MovementValidationException>()),
      );
    }
  });
}
