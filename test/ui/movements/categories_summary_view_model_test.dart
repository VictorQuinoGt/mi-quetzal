import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository repository;
  late MovementsViewModel vm;
  final date = DateTime(2026, 11, 2);
  setUp(() async {
    accounts = FakeAccountRepository();
    for (final type in [
      AccountType.bank,
      AccountType.creditCard,
      AccountType.bank,
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: 'Cuenta sintética',
          type: type,
          openingBalance: Money(
            type == AccountType.bank ? 10000 : 0,
            Currency.gtq,
          ),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    repository = FakeMovementRepository(accounts);
    vm = MovementsViewModel(repository, now: () => date);
    await vm.load();
  });
  tearDown(() => vm.dispose());
  Future<bool> record(
    MovementType type,
    int source,
    String amount, {
    int? category,
    int? other,
  }) => vm.createMovement(
    type: type,
    accountId: source,
    counterpartyAccountId: other,
    categoryId: category,
    amount: amount,
    description: 'Operación sintética',
    date: date,
  );

  test('Publica categorías compatibles y resumen completo aunque el historial esté filtrado', () async {
    expect(vm.summary!.currencies, isEmpty);
    await vm.createCategory(
      name: 'Gasto sintético',
      kind: CategoryKind.expense,
    );
    await vm.createCategory(
      name: 'Ingreso sintético',
      kind: CategoryKind.income,
    );
    expect(vm.categoriesFor(MovementType.expense).single.id, 1);
    expect(vm.categoriesFor(MovementType.income).single.id, 2);
    expect(vm.categoriesFor(MovementType.transfer), isEmpty);
    await record(MovementType.expense, 2, '5', category: 1);
    await record(MovementType.income, 1, '10', category: 2);
    await record(MovementType.creditPayment, 1, '2', other: 2);
    vm.searchFor('sin coincidencias');
    expect(vm.visibleMovements, isEmpty);
    expect(vm.summary!.currencies.single.expense.minorUnits, 500);
    expect(vm.summary!.currencies.single.income.minorUnits, 1000);
    expect(vm.summary!.currencies.single.difference.minorUnits, 500);
  });

  test('Categoriza y desasigna sin cambiar saldos ni identidad', () async {
    await record(MovementType.expense, 1, '1.25');
    await vm.createCategory(
      name: 'Gasto sintético',
      kind: CategoryKind.expense,
    );
    final id = vm.movements.single.id;
    vm.filterByCategory(null, uncategorizedOnly: true);
    expect(await vm.assignCategory(id, 1), isTrue);
    expect(vm.visibleMovements, isEmpty);
    expect(vm.accounts.first.currentBalance.minorUnits, 9875);
    expect(
      vm.summary!.currencies.single.expenseByCategory.single.categoryId,
      1,
    );
    expect(await vm.assignCategory(id, null), isTrue);
    expect(vm.movements.single.id, id);
    expect(vm.visibleMovements, hasLength(1));
    expect(vm.summary!.currencies.single.expense.minorUnits, 125);
  });

  test('Valida nombre y categoría antes de escribir y conserva selección tras fallar', () async {
    expect(
      await vm.createCategory(name: ' ', kind: CategoryKind.expense),
      isFalse,
    );
    expect(vm.fieldErrors, contains('name'));
    expect(repository.createCategoryCalls, 0);
    await vm.createCategory(
      name: 'Ingreso sintético',
      kind: CategoryKind.income,
    );
    expect(await record(MovementType.expense, 1, '1', category: 1), isFalse);
    expect(vm.fieldErrors, contains('category'));
    expect(repository.createCalls, 0);
    await record(MovementType.income, 1, '1');
    repository.failSave = true;
    expect(await vm.assignCategory(vm.movements.single.id, 1), isFalse);
    expect(vm.saveError, isNotNull);
    expect(vm.movements.single.details.categoryId, isNull);
    repository.failSave = false;
    expect(await vm.assignCategory(vm.movements.single.id, 1), isTrue);
  });

  test(
    'Bloquea comandos repetidos durante creación y categorización',
    () async {
      repository.saveGate = Completer<void>();
      final pending = vm.createCategory(
        name: 'Gasto sintético',
        kind: CategoryKind.expense,
      );
      expect(
        await vm.createCategory(
          name: 'Gasto sintético',
          kind: CategoryKind.expense,
        ),
        isFalse,
      );
      expect(repository.createCategoryCalls, 1);
      repository.saveGate!.complete();
      expect(await pending, isTrue);
      repository.saveGate = null;
      await record(MovementType.expense, 1, '1');
      repository.saveGate = Completer<void>();
      final assignment = vm.assignCategory(vm.movements.single.id, 1);
      expect(await vm.assignCategory(vm.movements.single.id, 1), isFalse);
      expect(repository.assignCategoryCalls, 1);
      repository.saveGate!.complete();
      expect(await assignment, isTrue);
    },
  );

  test('Navega entre años y rechaza meses futuros sin alterar el período', () {
    vm.selectSummaryMonth(DateTime(2026, 1));
    vm.previousSummaryMonth();
    expect(vm.summaryMonth, DateTime(2025, 12));
    vm.nextSummaryMonth();
    expect(vm.summaryMonth, DateTime(2026, 1));
    expect(
      () => vm.selectSummaryMonth(DateTime(2026, 12)),
      throwsArgumentError,
    );
    expect(vm.summaryMonth, DateTime(2026, 1));
    vm.selectSummaryMonth(DateTime(1900));
    expect(vm.canGoToPreviousMonth, isFalse);
    vm.selectSummaryMonth(date);
    expect(vm.canGoToNextMonth, isFalse);
  });

  test('Error de total agregado no revierte movimientos válidos ni muestra valores redondeados', () async {
    expect(await record(MovementType.expense, 1, '90071992547409.91'), isTrue);
    expect(await record(MovementType.expense, 3, '100.01'), isTrue);
    expect(vm.movements, hasLength(2));
    expect(vm.summary, isNull);
    expect(vm.summaryError, isNotNull);
    vm.previousSummaryMonth();
    expect(vm.summaryError, isNull);
    expect(vm.summary!.currencies, isEmpty);
  });
}
