import 'money.dart';

enum AccountType { cash, bank, creditCard }

enum BankAccountType { monetary, savings }

/// Datos de alta. El saldo inicial no es un ingreso ni un movimiento real.
final class AccountDetails {
  factory AccountDetails({
    required String name,
    required AccountType type,
    required Money openingBalance,
    required DateTime openingDate,
    Money? creditLimit,
    String? lastFour,
    BankAccountType? bankAccountType,
    Money? secondaryOpeningBalance,
    Money? secondaryCreditLimit,
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
    if (bankAccountType != null && type != AccountType.bank) {
      throw ArgumentError(
        'El tipo Monetaria o Ahorro corresponde a una cuenta bancaria.',
        'bankAccountType',
      );
    }
    if (secondaryOpeningBalance != null &&
        (type != AccountType.creditCard ||
            secondaryOpeningBalance.currency == openingBalance.currency ||
            secondaryOpeningBalance.minorUnits < 0)) {
      throw ArgumentError(
        'La segunda deuda debe ser cero o positiva y usar la otra moneda.',
        'secondaryOpeningBalance',
      );
    }
    if (secondaryCreditLimit != null &&
        (secondaryOpeningBalance == null ||
            secondaryCreditLimit.currency != secondaryOpeningBalance.currency ||
            secondaryCreditLimit.minorUnits < 0)) {
      throw ArgumentError(
        'Registra la segunda deuda y un límite cero o positivo en esa moneda.',
        'secondaryCreditLimit',
      );
    }
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
      bankAccountType: bankAccountType,
      secondaryOpeningBalance: secondaryOpeningBalance,
      secondaryCreditLimit: secondaryCreditLimit,
    );
  }

  const AccountDetails._({
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.openingDate,
    this.creditLimit,
    this.lastFour,
    this.bankAccountType,
    this.secondaryOpeningBalance,
    this.secondaryCreditLimit,
  });

  final String name;
  final AccountType type;
  final Money openingBalance;
  final DateTime openingDate;
  final Money? creditLimit;
  final String? lastFour;
  final BankAccountType? bankAccountType;
  final Money? secondaryOpeningBalance;
  final Money? secondaryCreditLimit;
  List<Money> get openingBalances => [openingBalance, ?secondaryOpeningBalance];
  Money? openingBalanceFor(Currency currency) {
    for (final balance in openingBalances) {
      if (balance.currency == currency) return balance;
    }
    return null;
  }
}

final class Account {
  Account({
    required this.id,
    required this.details,
    Money? currentBalance,
    Money? secondaryCurrentBalance,
  }) : currentBalance = currentBalance ?? details.openingBalance,
       secondaryCurrentBalance =
           secondaryCurrentBalance ?? details.secondaryOpeningBalance;
  final int id;
  final AccountDetails details;
  final Money currentBalance;
  final Money? secondaryCurrentBalance;
  List<Money> get currentBalances => [currentBalance, ?secondaryCurrentBalance];
  Money? balanceFor(Currency currency) {
    for (final balance in currentBalances) {
      if (balance.currency == currency) return balance;
    }
    return null;
  }

  bool get hasCreditInFavor =>
      details.type == AccountType.creditCard && currentBalance.minorUnits < 0;
  Money get displayBalance =>
      hasCreditInFavor ? currentBalance.absolute : currentBalance;
}
