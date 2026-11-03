import 'package:flutter/foundation.dart';

import '../../data/repositories/installment_repository.dart';
import '../../domain/models/installment_plan.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import '../movements/movements_view_model.dart';

class InstallmentFormViewModel extends ChangeNotifier {
  InstallmentFormViewModel(
    this.repository, {
    required this.ledger,
    required this.accountId,
    this.editing,
  });
  final InstallmentRepository repository;
  final MovementsViewModel ledger;
  final int accountId;
  final InstallmentPlan? editing;
  InstallmentDraft? preview;
  bool saving = false;
  bool _disposed = false;
  String? error;
  List<Installment> get previewRows => preview?.buildSchedule() ?? const [];
  List<Movement> eligibleOriginals(Currency currency) => ledger.movements
      .where(
        (m) =>
            m.details.accountId == accountId &&
            m.details.isExpense &&
            !m.details.isGenerated &&
            m.details.amount.currency == currency &&
            !ledger.installmentPlans.any(
              (p) => p.draft.originalMovementId == m.id,
            ),
      )
      .toList();
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool prepare({
    required String description,
    required Currency currency,
    required String original,
    required String count,
    required String monthly,
    required DateTime firstDate,
    required String day,
    required String previous,
    required DateTime reference,
    required InstallmentCostMode costMode,
    required InstallmentLimitMode limitMode,
    String principal = '',
    String interest = '',
    String fee = '',
    int? categoryId,
    int? originalMovementId,
  }) {
    preview = null;
    error = null;
    try {
      Money? optional(String input) =>
          input.trim().isEmpty ? null : Money.parse(input, currency);
      final amount = editing == null
          ? Money.parse(original, currency)
          : editing!.pendingPrincipal ??
                Money.fromBigInt(
                  BigInt.from(Money.parse(monthly, currency).minorUnits) *
                      BigInt.from(editing!.pending.length),
                  currency,
                );
      preview = InstallmentDraft(
        description: description,
        accountId: accountId,
        categoryId: categoryId,
        originalAmount: amount,
        count: editing == null ? int.parse(count) : editing!.pending.length,
        monthlyAmount: Money.parse(monthly, currency),
        firstDate: firstDate,
        chargeDay: int.parse(day),
        previousCount: editing == null ? int.parse(previous) : 0,
        referenceDate: editing == null ? reference : ledger.today,
        costMode: editing?.draft.costMode ?? costMode,
        limitMode: editing?.draft.limitMode ?? limitMode,
        monthlyPrincipal: optional(principal),
        monthlyInterest: optional(interest),
        monthlyFee: optional(fee),
        originalMovementId: editing == null ? originalMovementId : null,
      );
    } on InstallmentValidationException catch (e) {
      error = e.message;
    } on FormatException {
      error = 'Revisa importes, plazo, avance y día mensual. Usa números válidos y hasta dos decimales.';
    } on ArgumentError {
      error = 'Los importes superan el rango admitido.';
    }
    _emit();
    return preview != null;
  }

  Future<bool> save() async {
    if (saving || preview == null) return false;
    saving = true;
    error = null;
    _emit();
    try {
      final draft = preview!;
      if (editing == null) {
        await repository.createPlan(draft);
      } else {
        await repository.reviseFuture(
          editing!.id,
          description: draft.description,
          categoryId: draft.categoryId,
          monthly: draft.monthlyAmount,
          nextDate: draft.firstDate,
          chargeDay: draft.chargeDay,
          principal: draft.monthlyPrincipal,
          interest: draft.monthlyInterest,
          fee: draft.monthlyFee,
        );
      }
      await ledger.load();
      return true;
    } on InstallmentValidationException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'No se pudo guardar el plan. Conservamos el formulario; intenta de nuevo.';
      return false;
    } finally {
      saving = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
