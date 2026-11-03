import 'money.dart';
import 'financial_institution.dart';

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
    int? financialInstitutionId,
    DateTime? nextClosingDate,
    DateTime? nextPaymentDueDate,
  }) {
    final alias = name.trim();
    for (final date in [nextClosingDate, nextPaymentDueDate]) {
      if (date != null && (date.year < 1900 || date.year > 9999)) {
        throw ArgumentError(
          'Configura fechas completas entre 1900 y 9999.',
          'creditDates',
        );
      }
    }
    if (type != AccountType.creditCard &&
        (nextClosingDate != null || nextPaymentDueDate != null)) {
      throw ArgumentError(
        'Las fechas de corte y pago corresponden a tarjetas de crédito.',
        'creditDates',
      );
    }
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
        ((type != AccountType.creditCard && type != AccountType.bank) ||
            !RegExp(r'^\d{4}$').hasMatch(digits))) {
      throw ArgumentError(
        'Escribe únicamente los últimos cuatro dígitos.',
        'lastFour',
      );
    }
    if (financialInstitutionId != null &&
        (financialInstitutionId <= 0 || type == AccountType.cash)) {
      throw ArgumentError(
        'Selecciona una entidad financiera válida para una cuenta bancaria o tarjeta.',
        'financialInstitution',
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
      financialInstitutionId: financialInstitutionId,
      nextClosingDate: nextClosingDate == null
          ? null
          : DateTime(
              nextClosingDate.year,
              nextClosingDate.month,
              nextClosingDate.day,
            ),
      nextPaymentDueDate: nextPaymentDueDate == null
          ? null
          : DateTime(
              nextPaymentDueDate.year,
              nextPaymentDueDate.month,
              nextPaymentDueDate.day,
            ),
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
    this.financialInstitutionId,
    this.nextClosingDate,
    this.nextPaymentDueDate,
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
  final int? financialInstitutionId;
  final DateTime? nextClosingDate;
  final DateTime? nextPaymentDueDate;
  void validateFinancialInstitution(List<FinancialInstitution> institutions) {
    if (financialInstitutionId != null &&
        !institutions.any((i) => i.id == financialInstitutionId)) {
      throw ArgumentError(
        'Selecciona una entidad financiera existente.',
        'financialInstitution',
      );
    }
  }

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
    this.reservedCredit = const {},
    this.ordinaryDebt = const {},
    this.unknownAvailable = const {},
  }) : currentBalance = currentBalance ?? details.openingBalance,
       secondaryCurrentBalance =
           secondaryCurrentBalance ?? details.secondaryOpeningBalance;
  final int id;
  final AccountDetails details;
  final Money currentBalance;
  final Money? secondaryCurrentBalance;
  final Map<Currency, Money> reservedCredit;
  final Map<Currency, Money> ordinaryDebt;
  final Set<Currency> unknownAvailable;
  List<Money> get currentBalances => [currentBalance, ?secondaryCurrentBalance];
  Money? balanceFor(Currency currency) {
    for (final balance in currentBalances) {
      if (balance.currency == currency) return balance;
    }
    return null;
  }

  Money? creditLimitFor(Currency currency) =>
      details.creditLimit?.currency == currency
      ? details.creditLimit
      : details.secondaryCreditLimit?.currency == currency
      ? details.secondaryCreditLimit
      : null;
  Money? availableCreditFor(Currency currency) {
    if (details.type != AccountType.creditCard) return null;
    if (unknownAvailable.contains(currency)) return null;
    final balance = ordinaryDebt[currency] ?? balanceFor(currency);
    final limit = details.creditLimit?.currency == currency
        ? details.creditLimit
        : details.secondaryCreditLimit?.currency == currency
        ? details.secondaryCreditLimit
        : null;
    // Un saldo a favor no permite inferir cuánto autorizará el emisor.
    if (balance == null || limit == null || balance.minorUnits < 0) return null;
    final remaining =
        BigInt.from(limit.minorUnits) -
        BigInt.from(balance.minorUnits) -
        BigInt.from(reservedCredit[currency]?.minorUnits ?? 0);
    return Money.fromBigInt(
      remaining < BigInt.zero ? BigInt.zero : remaining,
      currency,
    );
  }

  bool get hasCreditInFavor =>
      details.type == AccountType.creditCard && currentBalance.minorUnits < 0;
  Money get displayBalance =>
      hasCreditInFavor ? currentBalance.absolute : currentBalance;
}
