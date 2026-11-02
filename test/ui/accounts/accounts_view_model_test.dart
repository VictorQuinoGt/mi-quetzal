import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/ui/accounts/accounts_view_model.dart';

import '../../support/fake_account_repository.dart';

void main() {
  late FakeAccountRepository repository;
  late AccountsViewModel vm;
  final date = DateTime(2026, 10, 1);

  Future<bool> save({
    String name = 'Cuenta sintética',
    String balance = '120.25',
    AccountType type = AccountType.bank,
    String limit = '',
    String digits = '',
    DateTime? openingDate,
  }) => vm.createAccount(
    name: name,
    type: type,
    currency: Currency.gtq,
    openingBalance: balance,
    openingDate: openingDate ?? date,
    creditLimit: limit,
    lastFour: digits,
  );

  setUp(() {
    repository = FakeAccountRepository();
    vm = AccountsViewModel(repository, now: () => date);
  });
  tearDown(() => vm.dispose());

  test('Expone carga, vacío y datos devueltos por el repositorio', () async {
    expect(vm.status, AccountsStatus.loading);
    await vm.load();
    expect(vm.status, AccountsStatus.ready);
    expect(vm.accounts, isEmpty);
    expect(await save(), isTrue);
    expect(
      vm.accounts.single.details.openingBalance,
      Money(12025, Currency.gtq),
    );
    expect(() => vm.accounts.clear(), throwsUnsupportedError);
  });

  test('Un error de carga permite reintentar sin borrar datos', () async {
    repository.failLoad = true;
    await vm.load();
    expect(vm.status, AccountsStatus.error);
    repository.failLoad = false;
    await vm.load();
    expect(vm.status, AccountsStatus.ready);
  });

  test(
    'Valida alias, precisión, efectivo, crédito y fecha antes de escribir',
    () async {
      await vm.load();
      expect(await save(name: ' '), isFalse);
      expect(vm.fieldErrors, contains('name'));
      expect(await save(balance: '1.001'), isFalse);
      expect(vm.fieldErrors, contains('openingBalance'));
      expect(await save(type: AccountType.cash, balance: '-1'), isFalse);
      expect(await save(type: AccountType.creditCard, balance: '-1'), isFalse);
      expect(
        await save(type: AccountType.creditCard, digits: '12345'),
        isFalse,
      );
      expect(vm.fieldErrors, contains('lastFour'));
      expect(await save(type: AccountType.creditCard, limit: '-1'), isFalse);
      expect(vm.fieldErrors, contains('creditLimit'));
      expect(
        await save(openingDate: date.add(const Duration(days: 1))),
        isFalse,
      );
      expect(vm.fieldErrors, contains('openingDate'));
      expect(repository.createCalls, 0);
    },
  );

  test('No aplica datos ocultos de tarjeta a una cuenta bancaria', () async {
    await vm.load();
    expect(await save(limit: '100', digits: '0042'), isTrue);
    expect(vm.accounts.single.details.creditLimit, isNull);
    expect(vm.accounts.single.details.lastFour, isNull);
  });

  test('Conserva listado al fallar un guardado y permite reintentar', () async {
    await vm.load();
    await save();
    repository.failSave = true;
    expect(await save(), isFalse);
    expect(vm.accounts, hasLength(1));
    expect(vm.saveError, isNotNull);
    expect(vm.isSaving, isFalse);
    repository.failSave = false;
    expect(await save(), isTrue);
    expect(vm.accounts, hasLength(2));
    expect(vm.saveError, isNull);
  });

  test('Ignora envíos repetidos mientras el guardado está en curso', () async {
    await vm.load();
    repository.saveGate = Completer<void>();
    final pending = save();
    expect(vm.isSaving, isTrue);
    expect(await save(), isFalse);
    expect(repository.createCalls, 1);
    repository.saveGate!.complete();
    expect(await pending, isTrue);
    expect(vm.accounts, hasLength(1));
  });
}
