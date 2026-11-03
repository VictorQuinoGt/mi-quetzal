import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';

AccountDetails details({
  AccountType type = AccountType.bank,
  int balance = 0,
  String name = 'Cuenta sintética',
  Money? limit,
  String? lastFour,
}) => AccountDetails(
  name: name,
  type: type,
  openingBalance: Money(balance, Currency.gtq),
  openingDate: DateTime(2026, 10, 1, 15),
  creditLimit: limit,
  lastFour: lastFour,
);

void main() {
  test('Conserva saldo bancario negativo y normaliza alias y fecha', () {
    final account = details(balance: -250, name: '  Cuenta sintética  ');
    expect(account.name, 'Cuenta sintética');
    expect(account.openingBalance.minorUnits, -250);
    expect(account.openingDate, DateTime(2026, 10, 1));
  });

  test('Efectivo y deuda inicial no aceptan cantidades negativas', () {
    for (final type in [AccountType.cash, AccountType.creditCard]) {
      expect(() => details(type: type, balance: -1), throwsArgumentError);
    }
  });

  test('No confunde deuda con límite ni exige conocer un límite', () {
    final credit = details(
      type: AccountType.creditCard,
      balance: 15000,
      limit: Money(10000, Currency.gtq),
      lastFour: '0042',
    );
    expect(credit.openingBalance.minorUnits, 15000);
    expect(credit.creditLimit!.minorUnits, 10000);
    expect(credit.lastFour, '0042');
    expect(details(type: AccountType.creditCard).creditLimit, isNull);
  });

  test(
    'Solo crédito admite límite; crédito y banco admiten terminación válida',
    () {
      expect(
        () => details(limit: Money(100, Currency.gtq)),
        throwsArgumentError,
      );
      expect(details(lastFour: '0042').lastFour, '0042');
      expect(
        () => details(type: AccountType.cash, lastFour: '0042'),
        throwsArgumentError,
      );
      expect(
        () => details(
          type: AccountType.creditCard,
          limit: Money(1, Currency.usd),
        ),
        throwsArgumentError,
      );
      expect(
        () => details(
          type: AccountType.creditCard,
          limit: Money(-1, Currency.gtq),
        ),
        throwsArgumentError,
      );
      for (final digits in ['123', '12345', 'abcd']) {
        expect(
          () => details(type: AccountType.creditCard, lastFour: digits),
          throwsArgumentError,
        );
      }
      expect(() => details(name: '  '), throwsArgumentError);
      expect(() => details(name: 'a' * 61), throwsArgumentError);
    },
  );
}
