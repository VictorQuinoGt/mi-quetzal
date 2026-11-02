import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository repository;
  late MovementsViewModel vm;
  setUp(() async {
    accounts = FakeAccountRepository();
    for (final entry in [
      (AccountType.bank, Currency.gtq),
      (AccountType.creditCard, Currency.gtq),
      (AccountType.cash, Currency.gtq),
      (AccountType.bank, Currency.usd),
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: 'Cuenta sintética',
          type: entry.$1,
          openingBalance: Money(1000, entry.$2),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: 1),
    );
    repository = FakeMovementRepository(accounts);
    for (final entry in [
      (MovementType.expense, 1, null, Currency.gtq, 'Compra sintética'),
      (MovementType.transfer, 1, 3, Currency.gtq, 'Transferencia sintética'),
      (MovementType.income, 4, null, Currency.usd, 'Ingreso sintético'),
    ]) {
      await repository.createMovement(
        MovementDetails(
          type: entry.$1,
          accountId: entry.$2,
          counterpartyAccountId: entry.$3,
          amount: Money(100, entry.$4),
          date: DateTime(2026, 10, repository.stored.length + 2),
          description: entry.$5,
        ),
      );
    }
    vm = MovementsViewModel(repository, now: () => DateTime(2026, 10, 5));
    await vm.load();
  });
  tearDown(() => vm.dispose());

  test(
    'Filtra ambos lados de transferencias y combina cuenta, tipo y moneda',
    () {
      vm.filterByAccount(3);
      expect(vm.visibleMovements.single.details.type, MovementType.transfer);
      vm.filterByType(MovementType.income);
      expect(vm.visibleMovements, isEmpty);
      vm.clearFilters();
      vm.filterByCurrency(Currency.usd);
      expect(vm.visibleMovements.single.details.isIncome, isTrue);
      expect(vm.movements, hasLength(3));
      expect(vm.accounts.first.currentBalance.minorUnits, 800);
    },
  );

  test(
    'Conserva filtros al recargar y los limpia sin cambiar saldos',
    () async {
      vm.searchFor(' COMPRA ');
      vm.filterByDates(DateTime(2026, 10, 2), DateTime(2026, 10, 2));
      await vm.load();
      expect(
        vm.visibleMovements.single.details.description,
        'Compra sintética',
      );
      expect(vm.filter.isActive, isTrue);
      expect(vm.accounts.first.currentBalance.minorUnits, 800);
      vm.clearFilters();
      expect(vm.visibleMovements, hasLength(3));
      expect(vm.search, isEmpty);
      expect(vm.filter.isActive, isFalse);
      expect(vm.accounts.first.currentBalance.minorUnits, 800);
    },
  );

  test(
    'Una compra fuera del filtro se guarda y actualiza el saldo completo',
    () async {
      vm.searchFor('Ingreso');
      final saved = await vm.createMovement(
        type: MovementType.expense,
        accountId: 1,
        amount: '0.50',
        description: 'Otra compra sintética',
        date: DateTime(2026, 10, 5),
      );
      expect(saved, isTrue);
      expect(vm.movements, hasLength(4));
      expect(vm.visibleMovements, hasLength(1));
      expect(vm.accounts.first.currentBalance.minorUnits, 750);
    },
  );

  test('Solo ofrece tarjetas del banco seleccionado y conserva su identidad al guardar', () async {
    expect(vm.debitCardsFor(1), hasLength(1));
    expect(vm.debitCardsFor(4), isEmpty);
    expect(
      await vm.createMovement(
        type: MovementType.expense,
        accountId: 1,
        debitCardId: 1,
        amount: '0.29',
        description: 'Compra con débito sintética',
        date: DateTime(2026, 10, 5),
      ),
      isTrue,
    );
    expect(vm.movements.first.details.debitCardId, 1);
    expect(vm.accounts.first.currentBalance.minorUnits, 771);
    expect(
      await vm.createMovement(
        type: MovementType.expense,
        accountId: 4,
        debitCardId: 1,
        amount: '0.29',
        description: 'Compra inválida sintética',
        date: DateTime(2026, 10, 5),
      ),
      isFalse,
    );
    expect(vm.fieldErrors, contains('debitCard'));
  });
}
