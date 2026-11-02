import 'money.dart';

enum AccountType { cash, bank, creditCard }

/// Datos de alta. El saldo inicial no es un ingreso ni un movimiento real.
final class AccountDetails {
  factory AccountDetails({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required DateTime openingDate,
    Money? creditLimit,
    String? lastFour,
  }) {
    final alias = name.trim();
    if (alias.isEmpty || alias.length > 60) {
      throw ArgumentError('Escribe un alias de 1 a 60 caracteres.', 'name');
    }
    if (type != AccountType.bank && openingBalance.minorUnits < 0) {
      throw ArgumentError(
        'El importe debe ser cero o positivo.',
        'openingBalance',
      );
    }
    if (creditLimit != null &&
        (type != AccountType.creditCard ||
            creditLimit.minorUnits < 0 ||
            creditLimit.currency != openingBalance.currency)) {
      throw ArgumentError(
        'El límite debe ser positivo o cero y usar la moneda de la tarjeta.',
        'creditLimit',
      );
    }
    final digits = lastFour?.trim();
    if (digits != null &&
        digits.isNotEmpty &&
        (type != AccountType.creditCard ||
            !RegExp(r'^\d{4}$').hasMatch(digits))) {
      throw ArgumentError(
        'Escribe únicamente los últimos cuatro dígitos.',
        'lastFour',
      );
    }
    return AccountDetails._(
      name: alias,
      type: type,
      openingBalance: openingBalance,
      openingDate: DateTime(
        openingDate.year,
        openingDate.month,
        openingDate.day,
      ),
      creditLimit: creditLimit,
      lastFour: digits == null || digits.isEmpty ? null : digits,
    );
  }

  const AccountDetails._({
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.openingDate,
    this.creditLimit,
    this.lastFour,
  });

  final String name;
  final AccountType type;
  final Money openingBalance;
  final DateTime openingDate;
  final Money? creditLimit;
  final String? lastFour;
}

final class Account {
  Account({required this.id, required this.details, Money? currentBalance})
    : currentBalance = currentBalance ?? details.openingBalance;
  final int id;
  final AccountDetails details;
  final Money currentBalance;
  bool get hasCreditInFavor =>
      details.type == AccountType.creditCard && currentBalance.minorUnits < 0;
  Money get displayBalance =>
      hasCreditInFavor ? currentBalance.absolute : currentBalance;
}
