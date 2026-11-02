import 'account.dart';

final class DebitCardValidationException implements Exception {
  const DebitCardValidationException(this.field, this.message);
  final String field;
  final String message;
  @override
  String toString() => message;
}

/// Un medio de pago: no tiene saldo ni moneda independientes de su banco.
final class DebitCardDetails {
  factory DebitCardDetails({
    required String name,
    required int accountId,
    String? lastFour,
  }) {
    final alias = name.trim();
    final digits = lastFour?.trim();
    if (alias.isEmpty || alias.length > 60) {
      throw const DebitCardValidationException(
        'name',
        'Escribe un alias de 1 a 60 caracteres.',
      );
    }
    if (accountId <= 0) {
      throw const DebitCardValidationException(
        'account',
        'Selecciona una cuenta bancaria.',
      );
    }
    if (digits != null &&
        digits.isNotEmpty &&
        !RegExp(r'^\d{4}$').hasMatch(digits)) {
      throw const DebitCardValidationException(
        'lastFour',
        'Escribe únicamente los últimos cuatro dígitos.',
      );
    }
    return DebitCardDetails._(
      name: alias,
      accountId: accountId,
      lastFour: digits == null || digits.isEmpty ? null : digits,
    );
  }
  const DebitCardDetails._({
    required this.name,
    required this.accountId,
    this.lastFour,
  });
  final String name;
  final int accountId;
  final String? lastFour;

  void validateAccount(List<Account> accounts) {
    if (!accounts.any(
      (a) => a.id == accountId && a.details.type == AccountType.bank,
    )) {
      throw const DebitCardValidationException(
        'account',
        'La tarjeta de débito debe vincularse a una cuenta bancaria existente.',
      );
    }
  }
}

final class DebitCard {
  const DebitCard({required this.id, required this.details});
  final int id;
  final DebitCardDetails details;
}
