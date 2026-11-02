import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/accounts/accounts_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

void main() {
  late FakeAccountRepository repository;
  late FakeMovementRepository movements;
  late AccountsViewModel vm;
  final today = DateTime(2026, 11, 2);
  setUp(() async {
    repository = FakeAccountRepository();
    await repository.createAccount(
      AccountDetails(
        name: 'Crédito sintético',
        type: AccountType.creditCard,
        openingBalance: Money(100, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    movements = FakeMovementRepository(repository);
    vm = AccountsViewModel(repository, now: () => today);
    await vm.load();
  });
  tearDown(() => vm.dispose());
  Future<bool> edit({
    String secondary = '',
    String limit = '',
    Currency currency = Currency.gtq,
  }) => vm.saveAccount(
    editingId: 1,
    name: 'Alias actualizado',
    type: AccountType.creditCard,
    currency: currency,
    openingBalance: '2.29',
    openingDate: DateTime(2026, 10, 1),
    secondaryOpeningBalance: secondary,
    secondaryCreditLimit: limit,
  );
  test('Valida deuda y límite de segunda moneda antes de escribir', () async {
    for (final value in ['-1', '1.001', 'texto']) {
      expect(await edit(secondary: value), isFalse);
      expect(vm.fieldErrors, contains('secondaryOpeningBalance'));
    }
    expect(await edit(limit: '100'), isFalse);
    expect(vm.fieldErrors, contains('secondaryCreditLimit'));
    expect(repository.updateCalls, 0);
  });
  test('Completa segunda moneda sin duplicar la cuenta y conserva precisión al recargar', () async {
    expect(await edit(secondary: '0.29', limit: '100'), isTrue);
    expect(vm.accounts, hasLength(1));
    expect(vm.accounts.single.id, 1);
    expect(vm.accounts.single.currentBalance.minorUnits, 229);
    expect(vm.accounts.single.secondaryCurrentBalance, Money(29, Currency.usd));
    await vm.load();
    expect(
      vm.accounts.single.details.secondaryCreditLimit,
      Money(10000, Currency.usd),
    );
    expect(await edit(currency: Currency.usd), isFalse);
    expect(vm.fieldErrors, contains('currency'));
  });
  test(
    'No elimina una moneda usada ni deja una actualización parcial al fallar',
    () async {
      await edit(secondary: '10');
      await movements.createMovement(
        MovementDetails(
          type: MovementType.expense,
          accountId: 1,
          amount: Money(125, Currency.usd),
          date: today,
          description: 'Compra USD sintética',
        ),
      );
      await vm.load();
      expect(await edit(), isFalse);
      expect(vm.fieldErrors, contains('secondaryOpeningBalance'));
      expect(vm.accounts.single.secondaryCurrentBalance!.minorUnits, 1125);
      repository.failSave = true;
      expect(await edit(secondary: '20'), isFalse);
      expect(vm.saveError, isNotNull);
      expect(vm.accounts.single.secondaryCurrentBalance!.minorUnits, 1125);
    },
  );
}
