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
  test('Recuperación compartida bloquea reintentos y devuelve una sola instantánea', () async {
    final repository = RefreshPlans();
    final vm = AppShellViewModel(installmentRepository: repository);
    addTearDown(vm.dispose);
    final first = vm.refreshInstallments();
    expect(await vm.refreshInstallments(), isNull);
    expect(repository.calls, 1);
    repository.gate.complete();
    expect(await first, isA<LedgerSnapshot>());
  });
  test('Recuperación fallida no reemplaza los datos confirmados', () async {
    final repository = RefreshPlans()..fail = true;
    repository.gate.complete();
    final vm = AppShellViewModel(installmentRepository: repository);
    addTearDown(vm.dispose);
    expect(await vm.refreshInstallments(), isNull);
    repository.fail = false;
    expect(await vm.refreshInstallments(), isA<LedgerSnapshot>());
  });
  test(
    'Cerrar la aplicación mientras recupera no recarga ViewModels descartados',
    () async {
      final repository = RefreshPlans();
      final vm = AppShellViewModel(installmentRepository: repository);
      final operation = vm.refreshInstallments();
      vm.dispose();
      repository.gate.complete();
      expect(await operation, isNull);
    },
  );
  test('Una actualización iniciada antes de guardar se descarta', () async {
    final repository = RefreshPlans();
    final vm = AppShellViewModel(installmentRepository: repository);
    addTearDown(vm.dispose);
    final pending = vm.refreshInstallments();
    vm.invalidateRefresh();
    repository.gate.complete();
    expect(await pending, isNull);
    expect(await vm.refreshInstallments(), isA<LedgerSnapshot>());
  });

  test('Una recuperación sin respuesta termina y permite reintentar', () async {
    final repository = RefreshPlans();
    final vm = AppShellViewModel(
      installmentRepository: repository,
      refreshTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(vm.dispose);
    expect(await vm.refreshInstallments(), isNull);
    repository.gate.complete();
    expect(await vm.refreshInstallments(), isA<LedgerSnapshot>());
  });
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
