import 'package:flutter/foundation.dart';

import '../../data/repositories/installment_repository.dart';
import '../../domain/models/installment_plan.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/money.dart';
import '../movements/movements_view_model.dart';

class InstallmentPlanViewModel extends ChangeNotifier {
  InstallmentPlanViewModel(
    this.repository, {
    required this.planId,
    required this.ledger,
  }) {
    ledger.addListener(notifyListeners);
  }
  final InstallmentRepository repository;
  final int planId;
  final MovementsViewModel ledger;
  bool busy = false;
  bool _disposed = false;
  String? error;
  InstallmentPlan? get plan =>
      ledger.installmentPlans.where((p) => p.id == planId).firstOrNull;
  String get originalCostLabel {
    final draft = plan!.draft;
    final zero = Money(0, draft.originalAmount.currency).compact;
    return switch (draft.costMode) {
      InstallmentCostMode.noInterest => 'Condición original: sin intereses',
      InstallmentCostMode.fixedBreakdown =>
        'Desglose mensual original: capital ${draft.monthlyPrincipal!.compact} · interés ${draft.monthlyInterest?.compact ?? zero} · comisión ${draft.monthlyFee?.compact ?? zero}',
      InstallmentCostMode.unknown =>
        'Condición original: capital e intereses sin desglose informado',
    };
  }

  List<Movement> reconciliationCandidates(Installment row) => ledger.movements
      .where(
        (m) =>
            !m.details.isGenerated &&
            m.details.isExpense &&
            m.details.accountId == plan?.draft.accountId &&
            m.details.amount == row.amount,
      )
      .toList();
  Future<void> _action(Future<void> Function() run) async {
    if (busy) return;
    busy = true;
    error = null;
    _emit();
    try {
      await run();
      await ledger.load();
    } on InstallmentValidationException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No se pudo completar la operación. El histórico se conserva; intenta de nuevo.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> cancel() => _action(() async {
    await repository.cancelPlan(planId);
  });
  Future<void> reconcile(int number, int source, String reference) =>
      _action(() async {
        await repository.reconcile(planId, number, source, reference);
      });
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ledger.removeListener(notifyListeners);
    super.dispose();
  }
}
