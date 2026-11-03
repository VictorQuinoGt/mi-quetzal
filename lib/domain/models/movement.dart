import 'money.dart';

enum MovementType { expense, income, transfer, creditPayment, refund }

enum MovementOrigin { manual, installmentCharge, installmentConversion }

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
    int? categoryId,
    int? originalMovementId,
    MovementOrigin origin = MovementOrigin.manual,
    int? installmentPlanId,
    int? installmentNumber,
    int? recognizedExpenseMinor,
    int? reconciledIntoId,
    bool reconciled = false,
    required Money amount,
    required DateTime date,
    required String description,
  }) {
    final text = description.trim();
    if (origin != MovementOrigin.manual &&
        (type != MovementType.expense ||
            installmentPlanId == null ||
            installmentPlanId <= 0 ||
            installmentNumber == null ||
            installmentNumber < 0 ||
            (origin == MovementOrigin.installmentCharge &&
                installmentNumber == 0) ||
            recognizedExpenseMinor == null ||
            recognizedExpenseMinor < 0 ||
            recognizedExpenseMinor > amount.minorUnits ||
            debitCardId != null)) {
      throw const MovementValidationException(
        'installment',
        'El cargo de cuota no es compatible con su plan.',
      );
    }
    if (origin == MovementOrigin.manual &&
        (installmentPlanId != null ||
            installmentNumber != null ||
            recognizedExpenseMinor != null)) {
      throw const MovementValidationException(
        'installment',
        'Los datos de cuota requieren un cargo generado por el plan.',
      );
    }
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
    if ((type == MovementType.refund) != (originalMovementId != null) ||
        (originalMovementId != null && originalMovementId <= 0)) {
      throw const MovementValidationException(
        'originalMovement',
        'La devolución debe estar vinculada a una compra o gasto existente.',
      );
    }
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
    if (categoryId != null &&
        type != MovementType.expense &&
        type != MovementType.income) {
      throw const MovementValidationException(
        'category',
        'Las categorías se aplican a ingresos y gastos, no a transferencias o pagos.',
      );
    }
    return MovementDetails._(
      type: type,
      accountId: accountId,
      counterpartyAccountId: counterpartyAccountId,
      debitCardId: debitCardId,
      categoryId: categoryId,
      originalMovementId: originalMovementId,
      amount: amount,
      date: DateTime(date.year, date.month, date.day),
      description: text,
      origin: origin,
      installmentPlanId: installmentPlanId,
      installmentNumber: installmentNumber,
      recognizedExpenseMinor: recognizedExpenseMinor,
      reconciledIntoId: reconciledIntoId,
      reconciled: reconciled,
    );
  }
  const MovementDetails._({
    required this.type,
    required this.accountId,
    required this.counterpartyAccountId,
    required this.debitCardId,
    required this.categoryId,
    required this.originalMovementId,
    required this.amount,
    required this.date,
    required this.description,
    required this.origin,
    required this.installmentPlanId,
    required this.installmentNumber,
    required this.recognizedExpenseMinor,
    required this.reconciledIntoId,
    required this.reconciled,
  });
  final MovementType type;
  final int accountId;
  final int? counterpartyAccountId;
  final int? debitCardId;
  final int? categoryId;
  final int? originalMovementId;
  final Money amount;
  final DateTime date;
  final String description;
  final MovementOrigin origin;
  final int? installmentPlanId;
  final int? installmentNumber;
  final int? recognizedExpenseMinor;
  final int? reconciledIntoId;
  final bool reconciled;
  bool get isGenerated => origin != MovementOrigin.manual;
  bool get isExpense =>
      type == MovementType.expense &&
      reconciledIntoId == null &&
      (recognizedExpenseMinor ?? amount.minorUnits) > 0;
  Money get reportExpense =>
      Money(recognizedExpenseMinor ?? amount.minorUnits, amount.currency);
  bool get isIncome => type == MovementType.income;
  bool get isRefund => type == MovementType.refund;

  MovementDetails withCategory(int? id) => MovementDetails(
    type: type,
    accountId: accountId,
    counterpartyAccountId: counterpartyAccountId,
    debitCardId: debitCardId,
    categoryId: id,
    originalMovementId: originalMovementId,
    origin: origin,
    installmentPlanId: installmentPlanId,
    installmentNumber: installmentNumber,
    recognizedExpenseMinor: recognizedExpenseMinor,
    reconciledIntoId: reconciledIntoId,
    reconciled: reconciled,
    amount: amount,
    date: date,
    description: description,
  );
}

final class Movement {
  const Movement({required this.id, required this.details});
  final int id;
  final MovementDetails details;
}
