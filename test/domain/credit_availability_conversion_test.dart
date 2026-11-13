import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';

void main() {
  Account credit({
    int debt = 150000,
    int? limit = 1100000,
    int reserved = 0,
    Set<Currency> unknown = const {},
    bool usdPrimary = false,
  }) => Account(
    id: 1,
    details: AccountDetails(
      name: 'Crédito sintético',
      type: AccountType.creditCard,
      openingBalance: Money(
        usdPrimary ? 0 : debt,
        usdPrimary ? Currency.usd : Currency.gtq,
      ),
      secondaryOpeningBalance: Money(
        usdPrimary ? debt : 0,
        usdPrimary ? Currency.gtq : Currency.usd,
      ),
      creditLimit: usdPrimary || limit == null
          ? null
          : Money(limit, Currency.gtq),
      secondaryCreditLimit: usdPrimary && limit != null
          ? Money(limit, Currency.gtq)
          : null,
      openingDate: DateTime(2026, 11, 1),
    ),
    reservedCredit: {Currency.gtq: Money(reserved, Currency.gtq)},
    unknownAvailable: unknown,
  );

  test('Convierte el disponible GTQ a USD a 7.8 sin cambiar deudas', () {
    final account = credit();
    expect(
      account.availableCreditFor(Currency.gtq),
      Money(950000, Currency.gtq),
    );
    expect(account.availableCreditUsdEquivalent, Money(121795, Currency.usd));
    expect(account.balanceFor(Currency.gtq), Money(150000, Currency.gtq));
    expect(account.balanceFor(Currency.usd), Money(0, Currency.usd));
    expect(account.creditLimitFor(Currency.usd), isNull);
  });

  test('Usa el disponible después de reservas y la moneda GTQ como fuente', () {
    for (final usdPrimary in [false, true]) {
      final account = credit(reserved: 170000, usdPrimary: usdPrimary);
      expect(account.availableCreditUsdEquivalent, Money(100000, Currency.usd));
    }
  });

  test(
    'Redondea al centavo más cercano con precisión entera en todo el rango',
    () {
      for (final entry in [
        (3, 0),
        (4, 1),
        (11, 1),
        (12, 2),
        (780, 100),
        (9007199254740991, 1154769135223204),
      ]) {
        expect(
          credit(debt: 0, limit: entry.$1).availableCreditUsdEquivalent,
          Money(entry.$2, Currency.usd),
        );
      }
    },
  );

  test(
    'Conserva cero y omite la conversión cuando el disponible GTQ es incierto',
    () {
      expect(
        credit(debt: 1200000).availableCreditUsdEquivalent,
        Money(0, Currency.usd),
      );
      expect(credit(limit: null).availableCreditUsdEquivalent, isNull);
      expect(
        credit(unknown: {Currency.gtq}).availableCreditUsdEquivalent,
        isNull,
      );
      final inFavor = Account(
        id: 1,
        details: credit().details,
        currentBalance: Money(-1, Currency.gtq),
      );
      expect(inFavor.availableCreditUsdEquivalent, isNull);
    },
  );
}
