import 'money.dart';

enum InstallmentCostMode { noInterest, fixedBreakdown, unknown }

enum InstallmentLimitMode { ordinary, additional }

enum InstallmentPlanState { active, completed, cancelled }

final class InstallmentValidationException implements Exception {
  const InstallmentValidationException(this.field, this.message);
  final String field;
  final String message;
  @override
  String toString() => message;
}

final class Installment {
  const Installment({
    required this.number,
    required this.date,
    required this.amount,
    this.principal,
    this.interest,
    this.fee,
    this.movementId,
    this.previouslyLoaded = false,
  });
  final int number;
  final DateTime date;
  final Money amount;
  final Money? principal;
  final Money? interest;
  final Money? fee;
  final int? movementId;
  final bool previouslyLoaded;
  bool get loaded => previouslyLoaded || movementId != null;
}

final class InstallmentDraft {
  InstallmentDraft({
    required String description,
    required this.accountId,
    this.categoryId,
    required this.originalAmount,
    required this.count,
    required this.monthlyAmount,
    required DateTime firstDate,
    required this.chargeDay,
    required this.previousCount,
    required DateTime referenceDate,
    required this.costMode,
    required this.limitMode,
    this.monthlyPrincipal,
    this.monthlyInterest,
    this.monthlyFee,
    this.originalMovementId,
  }) : description = description.trim(),
       firstDate = DateTime(firstDate.year, firstDate.month, firstDate.day),
       referenceDate = DateTime(
         referenceDate.year,
         referenceDate.month,
         referenceDate.day,
       ) {
    if (this.description.isEmpty || this.description.length > 100) {
      fail('description', 'Escribe una descripción de 1 a 100 caracteres.');
    }
    if (accountId <= 0) fail('account', 'Selecciona una tarjeta de crédito.');
    if (count < 1 ||
        count > 600 ||
        previousCount < 0 ||
        previousCount > count) {
      fail(
        'count',
        'Usa entre 1 y 600 cuotas y un avance entre cero y el plazo.',
      );
    }
    if (chargeDay < 1 || chargeDay > 31) {
      fail('chargeDay', 'El día mensual debe estar entre 1 y 31.');
    }
    if (originalAmount.minorUnits <= 0 ||
        monthlyAmount.minorUnits <= 0 ||
        originalAmount.currency != monthlyAmount.currency) {
      fail(
        'amount',
        'Los importes deben ser positivos y usar la misma moneda.',
      );
    }
    if (firstDate.year < 1900 ||
        firstDate.year > 9900 ||
        referenceDate.year < 1900 ||
        referenceDate.year > 9999) {
      fail('date', 'Revisa las fechas del plan.');
    }
    if (scheduledDate(0) != this.firstDate) {
      fail(
        'firstDate',
        'La primera fecha debe coincidir con el día mensual (o el último día de ese mes).',
      );
    }
    final principal = costMode == InstallmentCostMode.noInterest
        ? monthlyAmount
        : monthlyPrincipal;
    if (costMode != InstallmentCostMode.unknown) {
      if (principal == null ||
          principal.currency != originalAmount.currency ||
          principal.minorUnits <= 0 ||
          BigInt.from(principal.minorUnits) * BigInt.from(count - 1) >=
              BigInt.from(originalAmount.minorUnits)) {
        fail(
          'principal',
          'El capital mensual debe dejar una última cuota de capital positiva.',
        );
      }
      for (final value in [monthlyInterest, monthlyFee]) {
        if (value != null &&
            (value.currency != originalAmount.currency ||
                value.minorUnits < 0)) {
          fail(
            'costs',
            'Interés y comisión deben usar la misma moneda y no ser negativos.',
          );
        }
      }
      if (costMode == InstallmentCostMode.fixedBreakdown &&
          BigInt.from(principal.minorUnits) +
                  BigInt.from(monthlyInterest?.minorUnits ?? 0) +
                  BigInt.from(monthlyFee?.minorUnits ?? 0) !=
              BigInt.from(monthlyAmount.minorUnits)) {
        fail(
          'costs',
          'Capital, interés fijo y comisión fija deben sumar el importe mensual real.',
        );
      }
    } else {
      if (originalMovementId != null) {
        fail(
          'originalMovement',
          'Para vincular una compra completa, informa el capital de cada cuota o usa sin intereses.',
        );
      }
      if (BigInt.from(monthlyAmount.minorUnits) * BigInt.from(count) <
          BigInt.from(originalAmount.minorUnits)) {
        fail('amount', 'El total de mensualidades no cubre el monto original.');
      }
    }
    final schedule = buildSchedule();
    if (previousCount > 0 &&
        schedule[previousCount - 1].date.isAfter(this.referenceDate)) {
      fail(
        'referenceDate',
        'La referencia no puede ser anterior a la última cuota previamente cargada.',
      );
    }
    if (previousCount < count &&
        (previousCount == 0
            ? schedule.first.date.isBefore(this.referenceDate)
            : !schedule[previousCount].date.isAfter(this.referenceDate))) {
      fail(
        'referenceDate',
        'La siguiente cuota pendiente debe quedar después de la referencia; la primera puede coincidir si no hay cuotas previas.',
      );
    }
  }
  static Never fail(String field, String message) =>
      throw InstallmentValidationException(field, message);
  final String description;
  final int accountId;
  final int? categoryId;
  final Money originalAmount;
  final int count;
  final Money monthlyAmount;
  final DateTime firstDate;
  final int chargeDay;
  final int previousCount;
  final DateTime referenceDate;
  final InstallmentCostMode costMode;
  final InstallmentLimitMode limitMode;
  final Money? monthlyPrincipal;
  final Money? monthlyInterest;
  final Money? monthlyFee;
  final int? originalMovementId;
  DateTime scheduledDate(int index) {
    final month = DateTime(firstDate.year, firstDate.month + index);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(
      month.year,
      month.month,
      chargeDay > lastDay ? lastDay : chargeDay,
    );
  }

  List<Installment> buildSchedule() {
    final currency = originalAmount.currency;
    final fixedPrincipal = costMode == InstallmentCostMode.noInterest
        ? monthlyAmount.minorUnits
        : monthlyPrincipal?.minorUnits;
    final rows = <Installment>[];
    try {
      for (var index = 0; index < count; index++) {
        final principal = costMode == InstallmentCostMode.unknown
            ? null
            : Money.fromBigInt(
                index == count - 1
                    ? BigInt.from(originalAmount.minorUnits) -
                          BigInt.from(fixedPrincipal!) * BigInt.from(count - 1)
                    : BigInt.from(fixedPrincipal!),
                currency,
              );
        final interest = costMode == InstallmentCostMode.fixedBreakdown
            ? monthlyInterest ?? Money(0, currency)
            : Money(0, currency);
        final fee = costMode == InstallmentCostMode.fixedBreakdown
            ? monthlyFee ?? Money(0, currency)
            : Money(0, currency);
        final amount = principal == null
            ? monthlyAmount
            : principal.add(interest).add(fee);
        rows.add(
          Installment(
            number: index + 1,
            date: scheduledDate(index),
            amount: amount,
            principal: principal,
            interest: costMode == InstallmentCostMode.unknown ? null : interest,
            fee: costMode == InstallmentCostMode.unknown ? null : fee,
            previouslyLoaded: index < previousCount,
          ),
        );
      }
      Money.fromBigInt(
        rows.fold(
          BigInt.zero,
          (sum, row) => sum + BigInt.from(row.amount.minorUnits),
        ),
        currency,
      );
    } on ArgumentError {
      fail('amount', 'El calendario supera el rango de importes admitido.');
    }
    return List.unmodifiable(rows);
  }
}

final class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.draft,
    required this.schedule,
    required this.originalDescription,
    this.cancelled = false,
  });
  final int id;
  final InstallmentDraft draft;
  final String originalDescription;
  final List<Installment> schedule;
  final bool cancelled;
  int get loadedCount => schedule.where((row) => row.loaded).length;
  InstallmentPlanState get state => cancelled
      ? InstallmentPlanState.cancelled
      : loadedCount == schedule.length
      ? InstallmentPlanState.completed
      : InstallmentPlanState.active;
  List<Installment> get pending =>
      cancelled ? const [] : schedule.where((row) => !row.loaded).toList();
  Money get pendingAmount => Money.fromBigInt(
    pending.fold(
      BigInt.zero,
      (sum, row) => sum + BigInt.from(row.amount.minorUnits),
    ),
    draft.originalAmount.currency,
  );
  Money? get pendingPrincipal => pending.any((row) => row.principal == null)
      ? null
      : Money.fromBigInt(
          pending.fold(
            BigInt.zero,
            (sum, row) => sum + BigInt.from(row.principal!.minorUnits),
          ),
          draft.originalAmount.currency,
        );
  DateTime? get nextDate => pending.isEmpty ? null : pending.first.date;
}
