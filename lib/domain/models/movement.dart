import 'money.dart';

enum MovementType { expense, income, transfer, creditPayment }

final class MovementValidationException implements Exception {
  const MovementValidationException(this.field, this.message);
  final String field;
  final String message;
  @override
  String toString() => message;
}

final class MovementDetails {
  factory MovementDetails({
    required MovementType type,
    required int accountId,
    int? counterpartyAccountId,
    int? debitCardId,
    required Money amount,
    required DateTime date,
    required String description,
  }) {
    final text = description.trim();
    if (text.isEmpty || text.length > 120) {
      throw const MovementValidationException(
        'description',
        'Escribe una descripción de 1 a 120 caracteres.',
      );
    }
    if (amount.minorUnits <= 0) {
      throw const MovementValidationException(
        'amount',
        'El importe debe ser mayor que cero.',
      );
    }
    final needsOther =
        type == MovementType.transfer || type == MovementType.creditPayment;
    if (needsOther != (counterpartyAccountId != null)) {
      throw const MovementValidationException(
        'counterparty',
        'Revisa la cuenta de destino de la operación.',
      );
    }
    if (counterpartyAccountId == accountId) {
      throw const MovementValidationException(
        'counterparty',
        'El origen y el destino deben ser diferentes.',
      );
    }
    if (debitCardId != null && type != MovementType.expense) {
      throw const MovementValidationException(
        'debitCard',
        'La tarjeta de débito solo se selecciona para compras o gastos.',
      );
    }
    return MovementDetails._(
      type: type,
      accountId: accountId,
      counterpartyAccountId: counterpartyAccountId,
      debitCardId: debitCardId,
      amount: amount,
      date: DateTime(date.year, date.month, date.day),
      description: text,
    );
  }
  const MovementDetails._({
    required this.type,
    required this.accountId,
    required this.counterpartyAccountId,
    required this.debitCardId,
    required this.amount,
    required this.date,
    required this.description,
  });
  final MovementType type;
  final int accountId;
  final int? counterpartyAccountId;
  final int? debitCardId;
  final Money amount;
  final DateTime date;
  final String description;
  bool get isExpense => type == MovementType.expense;
  bool get isIncome => type == MovementType.income;
}

final class Movement {
  const Movement({required this.id, required this.details});
  final int id;
  final MovementDetails details;
}
