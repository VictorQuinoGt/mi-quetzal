import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/account_activity.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/accounts/account_detail_view_model.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository repository;
  late AccountDetailViewModel vm;
  final now = DateTime(2026, 1, 31);
  setUp(() async {
    accounts = FakeAccountRepository();
    for (final name in ['Banco elegido', 'Otro banco']) {
      await accounts.createAccount(
        AccountDetails(
          name: name,
          type: AccountType.bank,
          openingBalance: Money(10000, Currency.gtq),
          openingDate: DateTime(2025, 12, 1),
        ),
      );
    }
    await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: 1),
    );
    repository = FakeMovementRepository(accounts);
    for (final item in [
      (1, DateTime(2025, 12, 31)),
      (1, DateTime(2026, 1, 31)),
      (2, DateTime(2026, 1, 1)),
    ]) {
      await repository.createMovement(
        MovementDetails(
          type: MovementType.expense,
          accountId: item.$1,
          amount: Money(100, Currency.gtq),
          date: item.$2,
          description: 'Compra sintética',
        ),
      );
    }
    vm = AccountDetailViewModel(
      repository,
      target: const AccountDetailTarget.account(1),
      now: () => now,
    );
    await vm.load();
  });
  tearDown(() => vm.dispose());
  test('Contexto fijo, mes actual y enero a diciembre del año anterior', () {
    expect(vm.account!.id, 1);
    expect(vm.period, AccountPeriod.currentMonth);
    expect(vm.movements.single.id, 2);
    vm.selectPeriod(AccountPeriod.previousMonth);
    expect(vm.selectedMonth, DateTime(2025, 12));
    expect(vm.movements.single.id, 1);
    expect(vm.account!.currentBalance.minorUnits, 9800);
    vm.selectHistory(2025, 11);
    expect(vm.movements, isEmpty);
    expect(vm.account!.currentBalance.minorUnits, 9800);
  });
  test(
    'Los filtros globales no afectan al detalle y el detalle no los modifica',
    () async {
      final global = MovementsViewModel(repository, now: () => now);
      addTearDown(global.dispose);
      await global.load();
      global.filterByAccount(2);
      global.searchFor('sin coincidencias');
      global.filterByType(MovementType.income);
      global.filterByCurrency(Currency.usd);
      global.filterByDates(DateTime(2025, 12, 1), DateTime(2025, 12, 31));
      expect(global.visibleMovements, isEmpty);
      expect(vm.movements.single.id, 2);
      vm.selectHistory(2025, 12);
      expect(vm.movements.single.id, 1);
      expect(global.search, 'sin coincidencias');
      expect(global.filter.accountId, 2);
      expect(global.filter.type, MovementType.income);
      expect(global.filter.currency, Currency.usd);
      expect(global.filter.from, DateTime(2025, 12, 1));
    },
  );
  test('Recargar después de editar actualiza la cuenta y conserva el período elegido', () async {
    vm.selectHistory(2025, 12);
    await accounts.updateAccount(
      1,
      AccountDetails(
        name: 'Alias actualizado',
        type: AccountType.bank,
        openingBalance: Money(20000, Currency.gtq),
        openingDate: DateTime(2025, 12, 1),
      ),
    );
    await vm.load();
    expect(vm.name, 'Alias actualizado');
    expect(vm.account!.currentBalance.minorUnits, 19800);
    expect(vm.selectedMonth, DateTime(2025, 12));
    expect(vm.target.id, 1);
  });
  test('Valida histórico y cambio de año sin meses futuros ni selecciones imposibles', () {
    for (final date in [(1899, 12), (2026, 2), (2025, 13), (2025, 0)]) {
      expect(() => vm.selectHistory(date.$1, date.$2), throwsArgumentError);
    }
    vm.selectHistory(2025, 12);
    vm.selectHistoryYear(2026);
    expect(vm.selectedMonth, DateTime(2026, 1));
    expect(vm.availableMonths, [1]);
  });
  test(
    'Carga fallida permite reintentar y conserva contexto y período',
    () async {
      vm.selectHistory(2025, 12);
      repository.failLoad = true;
      await vm.load();
      expect(vm.ledger.status, MovementsStatus.error);
      repository.failLoad = false;
      await vm.load();
      expect(vm.ledger.status, MovementsStatus.ready);
      expect(vm.target.id, 1);
      expect(vm.selectedMonth, DateTime(2025, 12));
    },
  );
  test('Débito comparte saldo bancario y aclara el alcance cuando no hay identificación', () async {
    final debitVM = AccountDetailViewModel(
      repository,
      target: const AccountDetailTarget.debitCard(1),
      now: () => now,
    );
    addTearDown(debitVM.dispose);
    await debitVM.load();
    expect(debitVM.account!.id, 1);
    expect(debitVM.account!.currentBalance.minorUnits, 9800);
    expect(debitVM.debitScope, contains('cuenta bancaria vinculada'));
    expect(debitVM.movements.single.id, 2);
    expect(debitVM.ledger.accounts, hasLength(2));
  });
}
