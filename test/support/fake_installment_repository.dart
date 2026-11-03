import 'package:mi_quetzal/data/repositories/installment_repository.dart';
import 'package:mi_quetzal/domain/models/installment_plan.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';

import 'fake_movement_repository.dart';

class FakeInstallmentRepository implements InstallmentRepository {
  FakeInstallmentRepository(this.ledger);
  final FakeMovementRepository ledger;
  @override
  Future<LedgerSnapshot> generateDue() => ledger.getSnapshot();
  @override
  Future<LedgerSnapshot> createPlan(InstallmentDraft draft) =>
      throw UnimplementedError();
  @override
  Future<LedgerSnapshot> cancelPlan(int id) => throw UnimplementedError();
  @override
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
  }) => throw UnimplementedError();
  @override
  Future<LedgerSnapshot> reconcile(
    int planId,
    int number,
    int sourceMovementId,
    String reference,
  ) => throw UnimplementedError();
}
