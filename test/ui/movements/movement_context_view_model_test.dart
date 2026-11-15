import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/account_activity.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

void main() {
  late FakeMovementRepository repository;
  late MovementsViewModel vm;
  setUp(() async {
    final accounts = FakeAccountRepository();
    for (final entry in [
      ('Banco sintético', AccountType.bank, Currency.gtq),
      ('Crédito sintético', AccountType.creditCard, Currency.gtq),
      ('Banco USD', AccountType.bank, Currency.usd),
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: entry.$1,
          type: entry.$2,
          openingBalance: Money(10000, entry.$3),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: 1),
    );
    repository = FakeMovementRepository(accounts);
    vm = MovementsViewModel(repository, now: () => DateTime(2026, 11, 15));
    await vm.load();
  });
  tearDown(() => vm.dispose());

  test('Crédito ofrece compra y pago y cambia de origen a destino', () {
    const target = AccountDetailTarget.account(2);
    expect(vm.operationsFor(target), [
      MovementType.expense,
      MovementType.creditPayment,
    ]);
    expect(vm.defaultsFor(MovementType.expense, target).accountId, 2);
    expect(vm.defaultsFor(MovementType.expense, target).currency, Currency.gtq);
    final payment = vm.defaultsFor(MovementType.creditPayment, target);
    expect(payment.accountId, isNull);
    expect(payment.counterpartyId, 2);
    expect(payment.currency, isNull);
    expect(
      vm
          .originsFor(MovementType.creditPayment, target: target)
          .map((a) => a.id),
      [1],
    );
  });

  test('Débito conserva el banco y la identidad de la tarjeta', () {
    const target = AccountDetailTarget.debitCard(1);
    expect(vm.operationsFor(target), [MovementType.expense]);
    expect(vm.contextAccountFor(target)!.id, 1);
    final defaults = vm.defaultsFor(MovementType.expense, target);
    expect(defaults.accountId, 1);
    expect(defaults.debitCardId, 1);
  });

  test(
    'Una referencia ausente no se convierte en un registro general',
    () async {
      const target = AccountDetailTarget.debitCard(99);
      expect(vm.contextAccountFor(target), isNull);
      expect(vm.operationsFor(target), isEmpty);
      expect(
        await vm.createMovement(
          type: MovementType.expense,
          accountId: 1,
          target: target,
          amount: '1',
          description: 'Prueba',
          date: vm.today,
        ),
        isFalse,
      );
      expect(repository.createCalls, 0);
    },
  );

  test(
    'Rechaza otra cuenta, otro destino o quitar la tarjeta contextual',
    () async {
      for (final entry in [
        (AccountDetailTarget.account(1), MovementType.expense, 3, null, null),
        (
          AccountDetailTarget.account(2),
          MovementType.creditPayment,
          1,
          3,
          null,
        ),
        (AccountDetailTarget.debitCard(1), MovementType.expense, 1, null, null),
        (AccountDetailTarget.account(2), MovementType.income, 1, null, null),
      ]) {
        expect(
          await vm.createMovement(
            target: entry.$1,
            type: entry.$2,
            accountId: entry.$3,
            counterpartyAccountId: entry.$4,
            debitCardId: entry.$5,
            amount: '1',
            description: 'Prueba contextual',
            date: vm.today,
          ),
          isFalse,
        );
        expect(vm.fieldErrors, contains('account'));
      }
      expect(repository.createCalls, 0);
    },
  );
}
