import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/app/navigation/app_section.dart';
import 'package:mi_quetzal/app/navigation/app_shell_view_model.dart';

import 'dart:async';

import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';

import '../../support/fake_installment_repository.dart';
import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

class RefreshPlans extends FakeInstallmentRepository {
  RefreshPlans() : super(FakeMovementRepository(FakeAccountRepository()));
  final gate = Completer<void>();
  int calls = 0;
  bool fail = false;
  @override
  Future<LedgerSnapshot> generateDue() async {
    calls++;
    await gate.future;
    if (fail) throw StateError('Fallo sintético');
    return super.generateDue();
  }
}

void main() {
  test('Recuperación compartida bloquea reintentos simultáneos y recarga los lectores', () async {
    final repository = RefreshPlans();
    final vm = AppShellViewModel(installmentRepository: repository);
    addTearDown(vm.dispose);
    var reads = 0;
    Future<void> read() async {
      reads++;
    }

    final first = vm.refreshInstallments(() => [read, read]);
    await vm.refreshInstallments(() => [read]);
    expect(repository.calls, 1);
    expect(reads, 0);
    repository.gate.complete();
    await first;
    expect(reads, 2);
  });
  test(
    'Recuperación fallida deja que los lectores expongan su estado habitual',
    () async {
      final repository = RefreshPlans()..fail = true;
      repository.gate.complete();
      final vm = AppShellViewModel(installmentRepository: repository);
      addTearDown(vm.dispose);
      var reads = 0;
      await vm.refreshInstallments(
        () => [
          () async {
            reads++;
          },
        ],
      );
      expect(reads, 1);
    },
  );
  test(
    'Cerrar la aplicación mientras recupera no recarga ViewModels descartados',
    () async {
      final repository = RefreshPlans();
      final vm = AppShellViewModel(installmentRepository: repository);
      var reads = 0;
      final operation = vm.refreshInstallments(
        () => [
          () async {
            reads++;
          },
        ],
      );
      vm.dispose();
      repository.gate.complete();
      await operation;
      expect(reads, 0);
    },
  );
  test('Comienza en Inicio y notifica solo al cambiar de sección', () {
    final viewModel = AppShellViewModel();
    addTearDown(viewModel.dispose);
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    expect(viewModel.section, AppSection.home);
    viewModel.selectSection(AppSection.home);
    expect(notifications, 0);

    viewModel.selectSection(AppSection.accounts);
    expect(viewModel.section, AppSection.accounts);
    expect(notifications, 1);

    viewModel.selectSection(AppSection.accounts);
    expect(notifications, 1);

    viewModel.selectSection(AppSection.home);
    expect(viewModel.section, AppSection.home);
    expect(notifications, 2);
  });
}
