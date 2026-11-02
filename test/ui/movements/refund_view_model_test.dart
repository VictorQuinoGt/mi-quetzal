import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

void main() {
  late FakeMovementRepository repository;
  late MovementsViewModel vm;
  final today = DateTime(2026, 11, 2);
  setUp(() async {
    final accounts = FakeAccountRepository();
    await accounts.createAccount(
      AccountDetails(
        name: 'Crédito sintético',
        type: AccountType.creditCard,
        openingBalance: Money(0, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    repository = FakeMovementRepository(accounts);
    await repository.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: 1,
        amount: Money(500, Currency.usd),
        date: DateTime(2026, 10, 31),
        description: 'Compra sintética',
      ),
    );
    vm = MovementsViewModel(repository, now: () => today);
    await vm.load();
  });
  tearDown(() => vm.dispose());
  Future<bool> refund(String amount, {int originalId = 1, DateTime? date}) =>
      vm.refundPurchase(
        originalMovementId: originalId,
        amount: amount,
        description: 'Devolución sintética',
        date: date ?? today,
      );

  test('Deriva cuenta y moneda, actualiza pendiente y usa mes de devolución sin ingreso', () async {
    vm.searchFor('sin coincidencias');
    expect(await refund('1.25'), isTrue);
    expect(vm.visibleMovements, isEmpty);
    expect(vm.accounts.single.currentBalance.minorUnits, 375);
    expect(vm.remainingRefund(vm.movementById(1)!).minorUnits, 375);
    expect(vm.movements.first.details.amount.currency, Currency.usd);
    expect(vm.movements.first.details.accountId, 1);
    expect(vm.summary!.currencies.single.income.minorUnits, 0);
    expect(vm.summary!.currencies.single.expense.minorUnits, -125);
    vm.previousSummaryMonth();
    expect(vm.summary!.currencies.single.expense.minorUnits, 500);
  });
  test(
    'Valida vínculo, precisión, límite y fechas antes de llamar al repositorio',
    () async {
      expect(await refund('1', originalId: 999), isFalse);
      expect(vm.fieldErrors, contains('originalMovement'));
      for (final value in ['0', '-1', '1.001', '5.01']) {
        expect(await refund(value), isFalse);
        expect(vm.fieldErrors, contains('amount'));
      }
      expect(await refund('1', date: DateTime(2026, 10, 30)), isFalse);
      expect(vm.fieldErrors, contains('date'));
      expect(await refund('1', date: DateTime(2026, 11, 3)), isFalse);
      expect(repository.createCalls, 1);
    },
  );
  test('Bloquea repetición, conserva estado en fallo y reintenta una sola devolución', () async {
    repository.saveGate = Completer<void>();
    final pending = refund('2');
    expect(vm.isSaving, isTrue);
    expect(await refund('2'), isFalse);
    repository.failSave = true;
    repository.saveGate!.complete();
    expect(await pending, isFalse);
    expect(vm.saveError, isNotNull);
    expect(vm.remainingRefund(vm.movementById(1)!).minorUnits, 500);
    repository.failSave = false;
    expect(await refund('2'), isTrue);
    expect(vm.saveError, isNull);
    expect(vm.movements, hasLength(2));
  });
}
