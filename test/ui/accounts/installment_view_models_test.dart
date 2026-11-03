import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/installment_plan.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/ui/accounts/installment_form_view_model.dart';
import 'package:mi_quetzal/ui/accounts/installment_plan_view_model.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';
import '../../support/fake_installment_repository.dart';

class ControlledPlans extends FakeInstallmentRepository {
  ControlledPlans(super.ledger);
  int createCalls = 0;
  int cancelCalls = 0;
  bool fail = true;
  Completer<void>? gate;
  @override
  Future<LedgerSnapshot> createPlan(InstallmentDraft draft) async {
    createCalls++;
    await gate?.future;
    if (fail) throw StateError('Fallo sintético');
    return generateDue();
  }

  @override
  Future<LedgerSnapshot> cancelPlan(int id) async {
    cancelCalls++;
    await gate?.future;
    if (fail) {
      throw const InstallmentValidationException('plan', 'Error de prueba');
    }
    return generateDue();
  }
}

void main() {
  late MovementsViewModel ledger;
  late ControlledPlans repository;
  late InstallmentFormViewModel form;
  setUp(() async {
    final accounts = FakeAccountRepository();
    await accounts.createAccount(
      AccountDetails(
        name: 'Crédito sintético',
        type: AccountType.creditCard,
        openingBalance: Money(0, Currency.gtq),
        openingDate: DateTime(2026, 1, 1),
      ),
    );
    final movements = FakeMovementRepository(accounts);
    ledger = MovementsViewModel(movements, now: () => DateTime(2026, 1, 1));
    await ledger.load();
    repository = ControlledPlans(movements);
    form = InstallmentFormViewModel(repository, ledger: ledger, accountId: 1);
  });
  tearDown(() {
    form.dispose();
    ledger.dispose();
  });
  bool prepare({String original = '10.00'}) => form.prepare(
    description: 'Plan sintético',
    currency: Currency.gtq,
    original: original,
    count: '3',
    monthly: '3.33',
    firstDate: DateTime(2026, 1, 31),
    day: '31',
    previous: '0',
    reference: DateTime(2026, 1, 1),
    costMode: InstallmentCostMode.noInterest,
    limitMode: InstallmentLimitMode.ordinary,
  );
  test('Vista previa valida texto/centavos y guarda una sola vez mientras hay escritura', () async {
    expect(prepare(original: '1.001'), isFalse);
    expect(form.preview, isNull);
    expect(form.error, isNotEmpty);
    expect(prepare(), isTrue);
    expect(form.previewRows.map((r) => r.amount.minorUnits), [333, 333, 334]);
    repository.gate = Completer<void>();
    repository.fail = false;
    final first = form.save();
    expect(form.saving, isTrue);
    expect(await form.save(), isFalse);
    expect(repository.createCalls, 1);
    repository.gate!.complete();
    expect(await first, isTrue);
    expect(form.saving, isFalse);
  });
  test(
    'Error conserva formulario y calendario para reintentar sin éxito ficticio',
    () async {
      expect(prepare(), isTrue);
      expect(await form.save(), isFalse);
      expect(form.error, contains('No se pudo guardar'));
      expect(form.previewRows, hasLength(3));
      repository.fail = false;
      expect(await form.save(), isTrue);
      expect(repository.createCalls, 2);
      expect(form.error, isNull);
    },
  );
  test(
    'Plan bloquea doble acción y expone validación sin perder su estado',
    () async {
      final vm = InstallmentPlanViewModel(
        repository,
        planId: 1,
        ledger: ledger,
      );
      addTearDown(vm.dispose);
      repository.gate = Completer<void>();
      final first = vm.cancel();
      await vm.cancel();
      expect(repository.cancelCalls, 1);
      expect(vm.busy, isTrue);
      repository.gate!.complete();
      await first;
      expect(vm.busy, isFalse);
      expect(vm.error, 'Error de prueba');
      repository.fail = false;
      await vm.cancel();
      expect(repository.cancelCalls, 2);
      expect(vm.error, isNull);
    },
  );
}
