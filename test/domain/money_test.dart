import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/money.dart';

void main() {
  test('Convierte importes a centavos exactos sin punto flotante', () {
    for (final entry in {
      '0': 0,
      '0.29': 29,
      '0,10': 10,
      '1234.5': 123450,
      ' -12.34 ': -1234,
      '-0.00': 0,
      '90071992547409.91': 9007199254740991,
    }.entries) {
      expect(Money.parse(entry.key, Currency.gtq).minorUnits, entry.value);
    }
  });

  test('Rechaza importes ambiguos, redondeos y valores fuera de rango', () {
    for (final input in [
      '',
      '1,234',
      '1.234',
      '1,234.56',
      '1e3',
      'Q 10',
      'NaN',
      '1.',
      '.50',
      '90071992547409.92',
      '9999999999999999999999999999999',
    ]) {
      expect(
        () => Money.parse(input, Currency.gtq),
        throwsFormatException,
        reason: input,
      );
    }
  });

  test('Mantiene moneda explícita y representa signos y centavos', () {
    expect(Money(123456, Currency.gtq).formatted, 'GTQ 1,234.56');
    expect(Money(-1, Currency.usd).formatted, 'USD -0.01');
    expect(Money(100, Currency.gtq), isNot(Money(100, Currency.usd)));
    expect(Money.parse('1', Currency.gtq), Money(100, Currency.gtq));
  });
}
