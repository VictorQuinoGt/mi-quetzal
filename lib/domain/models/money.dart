enum Currency { gtq, usd }

extension CurrencyCode on Currency {
  String get code => name.toUpperCase();
}

/// Centavos enteros, dentro del rango exacto compartido por Dart y JavaScript.
final class Money {
  Money(this.minorUnits, this.currency) {
    if (BigInt.from(minorUnits).abs() > _maxExact) {
      throw ArgumentError.value(
        minorUnits,
        'minorUnits',
        'Importe fuera de rango',
      );
    }
  }

  static final _maxExact = BigInt.parse('9007199254740991');
  final int minorUnits;
  final Currency currency;

  factory Money.fromBigInt(BigInt minorUnits, Currency currency) {
    if (minorUnits.abs() > _maxExact) {
      throw ArgumentError('El total excede el rango de importes admitido.');
    }
    return Money(minorUnits.toInt(), currency);
  }

  Money add(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('No se pueden sumar monedas distintas.');
    }
    final total = BigInt.from(minorUnits) + BigInt.from(other.minorUnits);
    if (total.abs() > _maxExact) {
      throw ArgumentError('El saldo excede el rango de importes admitido.');
    }
    return Money(total.toInt(), currency);
  }

  Money get negated => Money(-minorUnits, currency);
  Money get absolute => Money(minorUnits.abs(), currency);
  String get input =>
      '${minorUnits < 0 ? '-' : ''}${minorUnits.abs() ~/ 100}.${(minorUnits.abs() % 100).toString().padLeft(2, '0')}';

  /// Acepta punto o coma decimal, sin separadores de miles ni redondeos.
  factory Money.parse(String input, Currency currency) {
    final value = input.trim();
    if (!RegExp(r'^-?\d+(?:[.,]\d{1,2})?$').hasMatch(value)) {
      throw const FormatException(
        'Usa un importe con hasta dos decimales, sin separadores de miles.',
      );
    }
    final parts = value.replaceFirst('-', '').split(RegExp(r'[.,]'));
    final cents = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
    var amount =
        BigInt.parse(parts[0]) * BigInt.from(100) + BigInt.parse(cents);
    if (value.startsWith('-')) amount = -amount;
    if (amount.abs() > _maxExact) {
      throw const FormatException('El importe es demasiado grande.');
    }
    return Money(amount.toInt(), currency);
  }

  String get formatted {
    final absolute = minorUnits.abs();
    final whole = (absolute ~/ 100).toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    final cents = (absolute % 100).toString().padLeft(2, '0');
    return '${currency.code} ${minorUnits < 0 ? '-' : ''}$whole.$cents';
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);
}
