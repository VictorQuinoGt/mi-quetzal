import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository repository;
  late MovementsViewModel vm;
  final date = DateTime(2026, 10, 2);
  Future<bool> save({
    MovementType type = MovementType.expense,
    int? account = 1,
    int? other,
    String amount = '1.29',
    String description = 'Operación sintética',
    DateTime? on,
  }) => vm.createMovement(
    type: type,
    accountId: account,
    counterpartyAccountId: other,
    amount: amount,
    description: description,
    date: on ?? date,
  );

  setUp(() async {
    accounts = FakeAccountRepository();
    for (final type in [
      AccountType.bank,
      AccountType.cash,
      AccountType.creditCard,
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: 'Cuenta sintética',
          type: type,
          openingBalance: Money(1000, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    await accounts.createAccount(
      AccountDetails(
        name: 'Cuenta USD sintética',
        type: AccountType.bank,
        openingBalance: Money(0, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    repository = FakeMovementRepository(accounts);
    vm = MovementsViewModel(repository, now: () => date);
  });
  tearDown(() => vm.dispose());

  test(
    'Carga estado vacío y publica historial y saldos después de guardar',
    () async {
      expect(vm.status, MovementsStatus.loading);
      await vm.load();
      expect(vm.movements, isEmpty);
      expect(await save(), isTrue);
      expect(vm.movements, hasLength(1));
      expect(vm.accounts.first.currentBalance, Money(871, Currency.gtq));
      expect(() => vm.movements.clear(), throwsUnsupportedError);
    },
  );

  test('Filtra origen por operación y destino por tipo y moneda', () async {
    await vm.load();
    expect(vm.originsFor(MovementType.expense), hasLength(4));
    expect(vm.originsFor(MovementType.income).map((a) => a.id), [1, 2, 4]);
    expect(vm.destinationsFor(MovementType.transfer, 1).map((a) => a.id), [2]);
    expect(vm.destinationsFor(MovementType.creditPayment, 1).map((a) => a.id), [
      3,
    ]);
    expect(vm.destinationsFor(MovementType.creditPayment, 4), isEmpty);
  });

  test('Valida entradas y referencias antes de pedir una escritura', () async {
    await vm.load();
    expect(await save(account: null), isFalse);
    expect(vm.fieldErrors, contains('account'));
    expect(await save(amount: '0.001'), isFalse);
    expect(vm.fieldErrors, contains('amount'));
    expect(await save(description: ' '), isFalse);
    expect(vm.fieldErrors, contains('description'));
    expect(await save(on: DateTime(2026, 10, 3)), isFalse);
    expect(vm.fieldErrors, contains('date'));
    expect(await save(type: MovementType.transfer), isFalse);
    expect(vm.fieldErrors, contains('counterparty'));
    expect(repository.createCalls, 0);
  });

  test('Un fallo al guardar conserva historial y permite reintentar', () async {
    await vm.load();
    await save();
    repository.failSave = true;
    expect(await save(), isFalse);
    expect(vm.saveError, isNotNull);
    expect(vm.movements, hasLength(1));
    repository.failSave = false;
    expect(await save(), isTrue);
    expect(vm.movements, hasLength(2));
    expect(vm.saveError, isNull);
  });

  test('Representa errores financieros devueltos por el repositorio', () async {
    await vm.load();
    expect(await save(account: 2, amount: '10.01'), isFalse);
    expect(vm.fieldErrors, contains('amount'));
    expect(vm.movements, isEmpty);
    expect(vm.accounts[1].currentBalance.minorUnits, 1000);
  });

  test(
    'Bloquea doble envío durante la escritura y restablece su estado',
    () async {
      await vm.load();
      repository.saveGate = Completer<void>();
      final pending = save();
      expect(vm.isSaving, isTrue);
      expect(await save(), isFalse);
      expect(repository.createCalls, 1);
      repository.saveGate!.complete();
      expect(await pending, isTrue);
      expect(vm.isSaving, isFalse);
      expect(vm.movements, hasLength(1));
    },
  );

  test('Un fallo de carga permite reintentar y reabrir limpia errores del formulario', () async {
    repository.failLoad = true;
    await vm.load();
    expect(vm.status, MovementsStatus.error);
    repository.failLoad = false;
    await vm.load();
    expect(vm.status, MovementsStatus.ready);
    await save(amount: '');
    expect(vm.fieldErrors, isNotEmpty);
    vm.startCreate();
    expect(vm.fieldErrors, isEmpty);
  });
}
