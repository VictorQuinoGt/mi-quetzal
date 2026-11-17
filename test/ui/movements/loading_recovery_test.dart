import '../../support/navigation.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/accounts/accounts_view_model.dart';
import 'package:mi_quetzal/ui/movements/movements_view.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/account_details.dart';
import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';
import '../../support/test_app.dart';

class ControlledAccounts extends FakeAccountRepository {
  Completer<List<DebitCard>>? cardRead;
  int reads = 0;
  @override
  Future<List<DebitCard>> getDebitCards() {
    reads++;
    return cardRead?.future ?? super.getDebitCards();
  }
}

class ControlledMovements extends FakeMovementRepository {
  ControlledMovements(super.accounts);
  Completer<LedgerSnapshot>? read;
  bool blockAfterSave = false;
  int reads = 0;
  @override
  Future<LedgerSnapshot> getSnapshot() {
    reads++;
    return read?.future ?? super.getSnapshot();
  }

  @override
  Future<LedgerSnapshot> createMovement(MovementDetails details) async {
    final saved = await super.createMovement(details);
    if (blockAfterSave) read = Completer<LedgerSnapshot>();
    return saved;
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  late ControlledAccounts accounts;
  late ControlledMovements repository;
  final today = DateTime(2026, 11, 15);
  setUp(() async {
    accounts = ControlledAccounts();
    for (final type in [AccountType.bank, AccountType.creditCard]) {
      await accounts.createAccount(
        AccountDetails(
          name: type == AccountType.bank
              ? 'Banco sintético'
              : 'Crédito sintético',
          type: type,
          openingBalance: Money(10000, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    repository = ControlledMovements(accounts);
  });

  Future<bool> save(MovementsViewModel vm) => vm.createMovement(
    type: MovementType.expense,
    accountId: 2,
    amount: '2.50',
    description: 'Compra sintética',
    date: today,
  );

  test(
    'Una primera lectura sin respuesta termina en error y permite reintentar',
    () async {
      final vm = MovementsViewModel(
        repository,
        loadTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(vm.dispose);
      final gate = Completer<LedgerSnapshot>();
      repository.read = gate;
      await vm.load();
      expect(vm.status, MovementsStatus.error);
      expect(vm.loadError, contains('tardando demasiado'));
      repository.read = null;
      await vm.load();
      expect(vm.status, MovementsStatus.ready);
      expect(vm.loadError, isNull);
      gate.complete(LedgerSnapshot.calculate([], []));
      await Future<void>.delayed(Duration.zero);
      expect(vm.accounts, hasLength(2));
    },
  );

  test(
    'Una lectura anterior no reemplaza un movimiento recién guardado',
    () async {
      final vm = MovementsViewModel(repository, now: () => today);
      addTearDown(vm.dispose);
      await vm.load();
      vm.searchFor('Compra');
      final old = repository.snapshot;
      final gate = Completer<LedgerSnapshot>();
      repository.read = gate;
      final loading = vm.load();
      expect(vm.status, MovementsStatus.ready);
      expect(await save(vm), isTrue);
      gate.complete(old);
      await loading;
      expect(vm.movements, hasLength(1));
      expect(vm.accounts.last.currentBalance.minorUnits, 10250);
      expect(vm.search, 'Compra');
    },
  );

  test(
    'Aplicar una instantánea confirmada descarta una carga pendiente',
    () async {
      final vm = MovementsViewModel(repository);
      addTearDown(vm.dispose);
      final old = LedgerSnapshot.calculate([], []);
      final gate = Completer<LedgerSnapshot>();
      repository.read = gate;
      final loading = vm.load();
      vm.applySnapshot(repository.snapshot);
      gate.complete(old);
      await loading;
      expect(vm.status, MovementsStatus.ready);
      expect(vm.accounts, hasLength(2));
    },
  );

  test('Fallo de actualización mantiene el historial confirmado y muestra el error', () async {
    final vm = MovementsViewModel(repository, now: () => today);
    addTearDown(vm.dispose);
    await vm.load();
    await save(vm);
    repository.failLoad = true;
    await vm.load();
    expect(vm.status, MovementsStatus.ready);
    expect(vm.movements, hasLength(1));
    expect(vm.loadError, isNotNull);
    repository.failLoad = false;
    await vm.load();
    expect(vm.loadError, isNull);
    expect(vm.movements, hasLength(1));
  });

  test(
    'Cuentas sale de la carga si la fuente no responde y puede recuperarse',
    () async {
      final vm = AccountsViewModel(
        accounts,
        loadTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(vm.dispose);
      final gate = Completer<List<DebitCard>>();
      accounts.cardRead = gate;
      await vm.load();
      expect(vm.status, AccountsStatus.error);
      vm.applySnapshot(repository.snapshot);
      expect(vm.status, AccountsStatus.ready);
      gate.complete([]);
      accounts.cardRead = null;
      await vm.load();
      expect(vm.status, AccountsStatus.ready);
      expect(vm.accounts, hasLength(2));
    },
  );

  Future<void> fillAndSave(WidgetTester tester) async {
    await tester.ensureVisible(field('Descripción'));
    await tester.enterText(field('Descripción'), 'Compra sintética');
    await tester.ensureVisible(field('Importe'));
    await tester.enterText(field('Importe'), '2.50');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();
    repository.blockAfterSave = true;
    await tester.tap(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Guardar desde una tarjeta actualiza todo sin nuevas lecturas aunque SQLite deje de responder',
    (tester) async {
      await tester.pumpWidget(
        testApp(repository: accounts, movements: repository),
      );
      await tester.pumpAndSettle();
      await selectAppSection(tester, 'Cuentas');
      await tester.pumpAndSettle();
      await openAccountDetails(tester, 2);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      final readsBefore = repository.reads;
      final accountReadsBefore = accounts.reads;
      await fillAndSave(tester);
      expect(repository.reads, readsBefore);
      expect(accounts.reads, accountReadsBefore);
      expect(repository.stored, hasLength(1));
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('GTQ 102.50'), findsOneWidget);
      await openHistory(tester);
      await tester.pumpAndSettle();
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      repository.read!.complete(repository.snapshot);
      await tester.pumpAndSettle();
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Una recarga demorada conserva la lista y permite reintentar al vencer',
    (tester) async {
      await tester.pumpWidget(
        testApp(repository: accounts, movements: repository),
      );
      await tester.pumpAndSettle();
      await openHistory(tester);
      await tester.pumpAndSettle();
      final vm = tester
          .widget<MovementsView>(find.byType(MovementsView))
          .viewModel;
      final gate = Completer<LedgerSnapshot>();
      repository.read = gate;
      final loading = vm.load();
      await tester.pump();
      expect(vm.status, MovementsStatus.ready);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 16));
      await loading;
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      repository.read = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsNothing);
      expect(vm.status, MovementsStatus.ready);
      gate.complete(LedgerSnapshot.calculate([], []));
      await tester.pumpAndSettle();
      expect(vm.accounts, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
