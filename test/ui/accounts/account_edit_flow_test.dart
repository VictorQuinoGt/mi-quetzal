import '../../support/movement_details.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';
import '../../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> press(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, Finder target, String label) async {
  await press(tester, target);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository movements;
  setUp(() async {
    accounts = FakeAccountRepository();
    await accounts.createAccount(
      AccountDetails(
        name: 'Banco sintético',
        type: AccountType.bank,
        bankAccountType: BankAccountType.monetary,
        openingBalance: Money(10000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await accounts.createAccount(
      AccountDetails(
        name: 'Crédito sintético',
        type: AccountType.creditCard,
        openingBalance: Money(500, Currency.gtq),
        secondaryOpeningBalance: Money(2000, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await accounts.createDebitCard(
      DebitCardDetails(
        name: 'Débito sintético',
        accountId: 1,
        lastFour: '0042',
      ),
    );
    movements = FakeMovementRepository(accounts);
  });
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
  }

  Future<void> record(
    int account,
    Currency currency,
    int cents, {
    int? debit,
  }) async {
    await movements.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: account,
        debitCardId: debit,
        amount: Money(cents, currency),
        date: DateTime(2026, 11, 1),
        description: 'Compra sintética',
      ),
    );
  }

  testWidgets(
    'Registra una sola tarjeta con aperturas y límites GTQ/USD visibles',
    (tester) async {
      await boot(tester);
      await press(tester, find.text('Agregar cuenta'));
      await tester.enterText(field('Alias'), 'Crédito nuevo sintético');
      await choose(
        tester,
        find.byType(DropdownButtonFormField<AccountType>),
        'Tarjeta de crédito',
      );
      await tester.enterText(field('Deuda inicial'), '10.29');
      await tester.enterText(field('Deuda inicial USD'), '20.01');
      await tester.ensureVisible(field('Límite de crédito USD (opcional)'));
      await tester.enterText(field('Límite de crédito USD (opcional)'), '500');
      await tester.ensureVisible(field('Límite de crédito (opcional)'));
      await tester.enterText(field('Límite de crédito (opcional)'), '1000');
      await press(tester, find.text('Guardar cuenta'));
      expect(accounts.stored, hasLength(3));
      expect(
        accounts.stored.last.details.secondaryOpeningBalance,
        Money(2001, Currency.usd),
      );
      expect(find.text('GTQ 10.29'), findsOneWidget);
      expect(find.text('USD 20.01'), findsOneWidget);
      expect(find.text('Límite de crédito: USD 500.00'), findsOneWidget);
    },
  );
  testWidgets(
    'Edita tarjeta vigente, conserva identidad y recalcula historial en USD',
    (tester) async {
      await record(2, Currency.usd, 125);
      await boot(tester);
      await press(tester, find.byTooltip('Editar Crédito sintético'));
      expect(
        tester
            .widget<DropdownButtonFormField<AccountType>>(
              find.byType(DropdownButtonFormField<AccountType>),
            )
            .onChanged,
        isNull,
      );
      await tester.enterText(field('Alias'), 'Crédito actualizado');
      await tester.enterText(field('Deuda inicial USD'), '30');
      await press(tester, find.text('Guardar cuenta'));
      expect(accounts.stored, hasLength(2));
      expect(find.text('Crédito actualizado'), findsOneWidget);
      expect(find.text('USD 31.25'), findsOneWidget);
      expect(find.text('GTQ 5.00'), findsOneWidget);
      expect(movements.stored.single.details.amount.minorUnits, 125);
      await tester.pumpWidget(const SizedBox());
      await boot(tester);
      expect(find.text('USD 31.25'), findsOneWidget);
    },
  );
  testWidgets(
    'Edita banco a Ahorro y muestra el mismo saldo en banco y débito',
    (tester) async {
      await record(1, Currency.gtq, 1000, debit: 1);
      await boot(tester);
      await press(tester, find.byTooltip('Editar Banco sintético'));
      await choose(
        tester,
        find.byType(DropdownButtonFormField<BankAccountType>),
        'Ahorro',
      );
      await tester.enterText(field('Saldo inicial'), '200');
      await press(tester, find.text('Guardar cuenta'));
      expect(find.text('GTQ 190.00'), findsNWidgets(2));
      expect(find.text('Cuentas bancarias'), findsOneWidget);
      expect(find.text('Ahorro'), findsOneWidget);
      expect(movements.snapshot.accounts, hasLength(2));
      await press(tester, find.byTooltip('Editar Débito sintético'));
      await tester.enterText(field('Alias de tarjeta'), 'Débito actualizado');
      await press(tester, find.text('Guardar tarjeta'));
      expect(find.text('Débito actualizado'), findsOneWidget);
      expect(accounts.cards.single.id, 1);
      expect(movements.stored.single.details.debitCardId, 1);
    },
  );
  testWidgets(
    'Compra USD y su devolución conservan GTQ intactos en una tarjeta dual',
    (tester) async {
      await boot(tester);
      await tester.tap(find.text('Movimientos'));
      await tester.pumpAndSettle();
      await press(tester, find.text('Registrar'));
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>).first,
        'Crédito sintético · GTQ / USD',
      );
      await choose(
        tester,
        find.byType(DropdownButtonFormField<Currency>),
        'USD',
      );
      await tester.enterText(field('Descripción'), 'Compra USD sintética');
      await tester.enterText(field('Importe'), '1.25');
      await press(tester, find.text('Guardar movimiento'));
      expect(movements.stored.single.details.amount.currency, Currency.usd);
      await openMovementDetails(tester, 1);
      await press(tester, find.text('Devolver'));
      await tester.enterText(
        field('Descripción de la devolución'),
        'Devolución USD sintética',
      );
      await tester.enterText(field('Importe a devolver'), '0.25');
      await press(tester, find.text('Guardar devolución'));
      expect(movements.stored.last.details.amount.currency, Currency.usd);
      await closeMovementDetails(tester);
      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();
      expect(find.text('GTQ 5.00'), findsOneWidget);
      expect(find.text('USD 21.00'), findsOneWidget);
    },
  );
  testWidgets(
    'Pago desde banco USD ofrece la tarjeta dual aunque su moneda principal sea GTQ',
    (tester) async {
      await accounts.createAccount(
        AccountDetails(
          name: 'Banco USD sintético',
          type: AccountType.bank,
          openingBalance: Money(5000, Currency.usd),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
      await boot(tester);
      await tester.tap(find.text('Movimientos'));
      await tester.pumpAndSettle();
      await press(tester, find.text('Registrar'));
      await choose(
        tester,
        find.byType(DropdownButtonFormField<MovementType>),
        'Pago de tarjeta',
      );
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>).first,
        'Banco USD sintético · USD',
      );
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>).last,
        'Crédito sintético',
      );
      await tester.enterText(field('Descripción'), 'Pago USD sintético');
      await tester.enterText(field('Importe'), '5');
      await press(tester, find.text('Guardar movimiento'));
      final card = movements.snapshot.accounts.singleWhere((a) => a.id == 2);
      expect(card.currentBalance.minorUnits, 500);
      expect(card.secondaryCurrentBalance!.minorUnits, 1500);
      expect(movements.snapshot.accounts.last.currentBalance.minorUnits, 4500);
    },
  );
  testWidgets(
    'Fallo al editar conserva datos y bloquea doble envío y volver durante reintento',
    (tester) async {
      await boot(tester);
      await press(tester, find.byTooltip('Editar Crédito sintético'));
      await tester.enterText(field('Alias'), 'Alias editado');
      accounts.failSave = true;
      await press(tester, find.text('Guardar cuenta'));
      expect(
        find.textContaining('No se pudo guardar la cuenta'),
        findsOneWidget,
      );
      expect(accounts.stored[1].details.name, 'Crédito sintético');
      accounts.failSave = false;
      accounts.saveGate = Completer<void>();
      await tester.tap(find.text('Guardar cuenta'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardando…'),
            )
            .onPressed,
        isNull,
      );
      await Navigator.of(tester.element(find.text('Editar cuenta'))).maybePop();
      await tester.pump();
      expect(find.text('Editar cuenta'), findsOneWidget);
      accounts.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(accounts.stored[1].details.name, 'Alias editado');
      expect(accounts.stored, hasLength(2));
    },
  );
  testWidgets(
    'Cuentas y edición dual caben a 320 px con teclado y texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await boot(tester);
      expect(tester.takeException(), isNull);
      await press(tester, find.byTooltip('Editar Crédito sintético'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(field('Deuda inicial USD'), '40.29');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar cuenta'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await press(tester, find.text('Guardar cuenta'));
      expect(
        accounts.stored[1].details.secondaryOpeningBalance!.minorUnits,
        4029,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
