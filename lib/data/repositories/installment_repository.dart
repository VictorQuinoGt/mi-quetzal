import '../../domain/models/installment_plan.dart';
import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/money.dart';

abstract interface class InstallmentRepository {
  Future<LedgerSnapshot> generateDue();
  Future<LedgerSnapshot> createPlan(InstallmentDraft draft);
  Future<LedgerSnapshot> cancelPlan(int id);
  Future<LedgerSnapshot> reviseFuture(
    int id, {
    required String description,
    required int? categoryId,
    required Money monthly,
    required DateTime nextDate,
    required int chargeDay,
    Money? principal,
    Money? interest,
    Money? fee,
  });
  Future<LedgerSnapshot> reconcile(
    int planId,
    int number,
    int sourceMovementId,
    String reference,
  );
}
