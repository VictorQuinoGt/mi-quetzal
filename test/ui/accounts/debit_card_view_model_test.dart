import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/ui/accounts/accounts_view_model.dart';

import '../../support/fake_account_repository.dart';

void main() {
  late FakeAccountRepository repository;
  late AccountsViewModel vm;
  setUp(() async {
    repository = FakeAccountRepository();
    for (final type in [
      AccountType.bank,
      AccountType.cash,
      AccountType.creditCard,
    ]) {
      await repository.createAccount(
        AccountDetails(
          name: 'Cuenta sintética',
          type: type,
          openingBalance: Money(1000, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    vm = AccountsViewModel(repository);
    await vm.load();
  });
  tearDown(() => vm.dispose());

  test('Lista bancos y crea tarjetas sin agregar cuentas ni saldos', () async {
    expect(vm.bankAccounts.map((a) => a.id), [1]);
    expect(
      await vm.createDebitCard(
        name: 'Débito sintético',
        accountId: 1,
        lastFour: '0042',
      ),
      isTrue,
    );
    expect(
      await vm.createDebitCard(name: 'Otro débito sintético', accountId: 1),
      isTrue,
    );
    expect(vm.debitCards, hasLength(2));
    expect(vm.accounts, hasLength(3));
    expect(vm.accounts.first.currentBalance, Money(1000, Currency.gtq));
    await vm.load();
    expect(vm.debitCards.first.details.lastFour, '0042');
    expect(() => vm.debitCards.clear(), throwsUnsupportedError);
  });

  test('Valida alias, banco y últimos cuatro antes de escribir', () async {
    expect(await vm.createDebitCard(name: ' ', accountId: 1), isFalse);
    expect(vm.fieldErrors, contains('name'));
    for (final id in [null, 2, 3, 999]) {
      expect(
        await vm.createDebitCard(name: 'Débito sintético', accountId: id),
        isFalse,
      );
      expect(vm.fieldErrors, contains('account'));
    }
    expect(
      await vm.createDebitCard(
        name: 'Débito sintético',
        accountId: 1,
        lastFour: '12345',
      ),
      isFalse,
    );
    expect(vm.fieldErrors, contains('lastFour'));
    expect(repository.createCardCalls, 0);
  });

  test('Un fallo conserva el listado y permite reintentar', () async {
    repository.failSave = true;
    expect(
      await vm.createDebitCard(name: 'Débito sintético', accountId: 1),
      isFalse,
    );
    expect(vm.saveError, isNotNull);
    expect(vm.debitCards, isEmpty);
    repository.failSave = false;
    expect(
      await vm.createDebitCard(name: 'Débito sintético', accountId: 1),
      isTrue,
    );
    expect(vm.saveError, isNull);
    expect(vm.debitCards, hasLength(1));
  });

  test('Bloquea envíos repetidos durante el guardado de una tarjeta', () async {
    repository.saveGate = Completer<void>();
    final pending = vm.createDebitCard(name: 'Débito sintético', accountId: 1);
    expect(vm.isSaving, isTrue);
    expect(
      await vm.createDebitCard(name: 'Débito sintético', accountId: 1),
      isFalse,
    );
    expect(repository.createCardCalls, 1);
    repository.saveGate!.complete();
    expect(await pending, isTrue);
    expect(vm.debitCards, hasLength(1));
    expect(vm.isSaving, isFalse);
  });
}
