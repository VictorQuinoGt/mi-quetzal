import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/accounts/account_detail_view_model.dart';

import '../../support/account_details.dart';
import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';
import '../../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Finder dropdown(String label) => find.byWidgetPredicate(
  (w) => w is DropdownButtonFormField<int> && w.decoration.labelText == label,
);

Future<void> press(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
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

Future<void> fill(
  WidgetTester tester, {
  String description = 'Compra sintética',
  String amount = '12.50',
}) async {
  await tester.ensureVisible(field('Descripción'));
  await tester.enterText(field('Descripción'), description);
  await tester.ensureVisible(field('Importe'));
  await tester.enterText(field('Importe'), amount);
}

Future<void> openMovement(
  WidgetTester tester, {
  String operation = 'Gasto',
}) async {
  await press(tester, find.byType(FloatingActionButton));
  await press(tester, find.text(operation));
}

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository movements;
  setUp(() async {
    accounts = FakeAccountRepository();
    for (final entry in [
      ('Banco sintético', AccountType.bank, Currency.gtq),
      ('Crédito sintético', AccountType.creditCard, Currency.gtq),
      ('Efectivo sintético', AccountType.cash, Currency.gtq),
      ('Banco USD', AccountType.bank, Currency.usd),
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: entry.$1,
          type: entry.$2,
          openingBalance: Money(10000, entry.$3),
          secondaryOpeningBalance: entry.$2 == AccountType.creditCard
              ? Money(2000, Currency.usd)
              : null,
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: 1),
    );
    movements = FakeMovementRepository(accounts);
  });

  Future<void> boot(
    WidgetTester tester,
    int id, {
    bool debit = false,
    String operation = 'Gasto',
  }) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuentas').last);
    await tester.pumpAndSettle();
    await openAccountDetails(tester, id, debit: debit);
    await openMovement(tester, operation: operation);
  }

  for (final entry in [(1, 8750), (2, 11250), (3, 8750)]) {
    testWidgets(
      'Registra desde la cuenta ${entry.$1} y vuelve al detalle con saldo actualizado',
      (tester) async {
        await boot(tester, entry.$1);
        final origin = tester.widget<DropdownButtonFormField<int>>(
          dropdown('Cuenta o tarjeta'),
        );
        expect(origin.initialValue, entry.$1);
        expect(origin.onChanged, isNull);
        await fill(tester);
        await press(tester, find.text('Guardar movimiento'));
        expect(find.text('Registrar gasto'), findsNothing);
        expect(find.text('Movimientos del período'), findsOneWidget);
        expect(find.text('Compra sintética'), findsOneWidget);
        expect(movements.stored.single.details.accountId, entry.$1);
        expect(
          movements.snapshot.accounts
              .singleWhere((a) => a.id == entry.$1)
              .currentBalance
              .minorUnits,
          entry.$2,
        );
        await closeAccountDetails(tester);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          2,
        );
        expect(
          find.text(Money(entry.$2, Currency.gtq).formatted),
          findsWidgets,
        );
        await tester.tap(find.text('Movimientos').last);
        await tester.pumpAndSettle();
        expect(find.text('Compra sintética'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'El botón solo muestra más y permite elegir o cancelar antes del formulario',
    (tester) async {
      await tester.pumpWidget(
        testApp(repository: accounts, movements: movements),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuentas').last);
      await tester.pumpAndSettle();
      await openAccountDetails(tester, 2);
      expect(find.text('Registrar movimiento'), findsNothing);
      expect(
        find.byTooltip('Registrar movimiento en Crédito sintético'),
        findsOneWidget,
      );
      await press(tester, find.byType(FloatingActionButton));
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('Pago'), findsOneWidget);
      expect(find.text('Registrar gasto'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await Navigator.of(tester.element(find.text('Gasto'))).maybePop();
      await tester.pumpAndSettle();
      expect(movements.stored, isEmpty);
      expect(find.text('Movimientos del período'), findsOneWidget);
      await openMovement(tester, operation: 'Pago');
      expect(find.text('Registrar pago'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<MovementType>), findsNothing);
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              dropdown('Tarjeta de destino'),
            )
            .initialValue,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Débito queda seleccionado y descuenta una sola vez el banco vinculado',
    (tester) async {
      await boot(tester, 1, debit: true);
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(dropdown('Cuenta o tarjeta'))
            .initialValue,
        1,
      );
      final card = tester.widget<DropdownButtonFormField<int>>(
        dropdown('Tarjeta de débito (opcional)'),
      );
      expect(card.initialValue, 1);
      expect(card.onChanged, isNull);
      expect(find.byType(DropdownButtonFormField<MovementType>), findsNothing);
      await fill(tester);
      await press(tester, find.text('Guardar movimiento'));
      expect(movements.stored.single.details.debitCardId, 1);
      expect(movements.snapshot.accounts.first.currentBalance.minorUnits, 8750);
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(find.text('GTQ 87.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Compra USD en crédito conserva independiente la deuda GTQ', (
    tester,
  ) async {
    await boot(tester, 2);
    await choose(tester, find.byType(DropdownButtonFormField<Currency>), 'USD');
    await fill(tester, amount: '5');
    await press(tester, find.text('Guardar movimiento'));
    expect(movements.stored.single.details.amount, Money(500, Currency.usd));
    final credit = movements.snapshot.accounts.singleWhere((a) => a.id == 2);
    expect(credit.currentBalance.minorUnits, 10000);
    expect(credit.secondaryCurrentBalance!.minorUnits, 2500);
    expect(find.text('Compra sintética'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pagar crédito fija su destino y exige origen explícito en la misma moneda',
    (tester) async {
      await boot(tester, 2, operation: 'Pago');
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(dropdown('Cuenta de origen'))
            .initialValue,
        isNull,
      );
      final destination = tester.widget<DropdownButtonFormField<int>>(
        dropdown('Tarjeta de destino'),
      );
      expect(destination.initialValue, 2);
      expect(destination.onChanged, isNull);
      await fill(tester, description: 'Pago sintético', amount: '5');
      await press(tester, find.text('Guardar movimiento'));
      expect(movements.stored, isEmpty);
      expect(find.text('Selecciona una cuenta.'), findsOneWidget);
      await choose(tester, dropdown('Cuenta de origen'), 'Banco USD · USD');
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              dropdown('Tarjeta de destino'),
            )
            .initialValue,
        2,
      );
      await press(tester, find.text('Guardar movimiento'));
      final saved = movements.stored.single.details;
      expect(saved.type, MovementType.creditPayment);
      expect(saved.accountId, 4);
      expect(saved.counterpartyAccountId, 2);
      expect(saved.amount.currency, Currency.usd);
      expect(
        movements.snapshot.accounts
            .singleWhere((a) => a.id == 4)
            .currentBalance
            .minorUnits,
        9500,
      );
      expect(
        movements.snapshot.accounts
            .singleWhere((a) => a.id == 2)
            .secondaryCurrentBalance!
            .minorUnits,
        1500,
      );
      expect(find.text('Pago sintético'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final type in [MovementType.income, MovementType.transfer]) {
    testWidgets('Elegir ${type.name} conserva la cuenta seleccionada', (
      tester,
    ) async {
      await boot(
        tester,
        1,
        operation: type == MovementType.income ? 'Ingreso' : 'Transferencia',
      );
      final origin = tester.widget<DropdownButtonFormField<int>>(
        dropdown(
          type == MovementType.income ? 'Cuenta receptora' : 'Cuenta de origen',
        ),
      );
      expect(origin.initialValue, 1);
      expect(origin.onChanged, isNull);
      if (type == MovementType.transfer) {
        await choose(
          tester,
          dropdown('Cuenta de destino'),
          'Efectivo sintético',
        );
      }
      await fill(tester);
      await press(tester, find.text('Guardar movimiento'));
      expect(movements.stored.single.details.type, type);
      expect(movements.stored.single.details.accountId, 1);
      expect(
        movements.snapshot.accounts.first.currentBalance.minorUnits,
        type == MovementType.income ? 11250 : 8750,
      );
      expect(find.text('Movimientos del período'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Cancelar no escribe y conserva el período del detalle', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuentas').last);
    await tester.pumpAndSettle();
    await openAccountDetails(tester, 2);
    await choose(
      tester,
      find.byType(DropdownButtonFormField<AccountPeriod>),
      'Mes anterior',
    );
    await openMovement(tester);
    await fill(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(movements.stored, isEmpty);
    expect(find.text('Mes anterior'), findsOneWidget);
    expect(find.text('Crédito sintético'), findsOneWidget);
  });

  testWidgets(
    'Guardar conserva el período y actualiza los detalles bancario y débito apilados',
    (tester) async {
      await tester.pumpWidget(
        testApp(repository: accounts, movements: movements),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cuentas').last);
      await tester.pumpAndSettle();
      await openAccountDetails(tester, 1);
      await press(tester, find.text('Débito sintético'));
      await choose(
        tester,
        find.byType(DropdownButtonFormField<AccountPeriod>),
        'Mes anterior',
      );
      await openMovement(tester);
      await fill(tester);
      await press(tester, find.text('Guardar movimiento'));
      expect(find.text('Mes anterior'), findsOneWidget);
      expect(find.text('Compra sintética'), findsNothing);
      expect(find.text('GTQ 87.50'), findsOneWidget);
      await closeAccountDetails(tester);
      expect(find.text('Banco sintético'), findsOneWidget);
      expect(find.text('GTQ 87.50'), findsOneWidget);
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sin origen compatible permite efectivo en agencia y conserva la moneda',
    (tester) async {
      await accounts.createAccount(
        AccountDetails(
          name: 'Crédito sin origen USD',
          type: AccountType.creditCard,
          openingBalance: Money(1000, Currency.usd),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
      accounts.stored.removeWhere((a) => a.id == 4);
      await boot(tester, 5, operation: 'Pago');
      expect(dropdown('Cuenta de origen'), findsNothing);
      expect(
        tester
            .widget<DropdownButtonFormField<PaymentFunding>>(
              find.byType(DropdownButtonFormField<PaymentFunding>),
            )
            .initialValue,
        PaymentFunding.externalCash,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              dropdown('Tarjeta de destino'),
            )
            .initialValue,
        5,
      );
      await fill(tester);
      await press(tester, find.text('Guardar movimiento'));
      final payment = movements.stored.single.details;
      expect(payment.paymentFunding, PaymentFunding.externalCash);
      expect(payment.accountId, 5);
      expect(payment.counterpartyAccountId, isNull);
      expect(payment.amount.currency, Currency.usd);
      expect(
        movements.snapshot.accounts
            .singleWhere((a) => a.id == 5)
            .currentBalance
            .minorUnits,
        -250,
      );
      expect(
        movements.snapshot.accounts
            .singleWhere((a) => a.id == 1)
            .currentBalance
            .minorUnits,
        10000,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Un fallo conserva campos y contexto; una escritura bloquea doble envío y volver',
    (tester) async {
      await boot(tester, 2);
      await fill(tester);
      movements.failSave = true;
      await press(tester, find.text('Guardar movimiento'));
      expect(find.text('Registrar gasto'), findsOneWidget);
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(dropdown('Cuenta o tarjeta'))
            .initialValue,
        2,
      );
      movements.failSave = false;
      final gate = Completer<void>();
      movements.saveGate = gate;
      await tester.tap(find.text('Guardar movimiento'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardando…'),
            )
            .onPressed,
        isNull,
      );
      await Navigator.of(tester.element(find.text('Registrar gasto')))
          .maybePop();
      await tester.pump();
      expect(find.text('Registrar gasto'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(movements.stored, hasLength(1));
      expect(movements.stored.single.details.accountId, 2);
      expect(find.text('Movimientos del período'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'El acceso y formulario contextual caben en 320 px con texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await boot(tester, 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await fill(tester);
      await press(tester, find.text('Guardar movimiento'));
      expect(movements.stored.single.details.accountId, 2);
      expect(find.text('Movimientos del período'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Registra desde crédito una fecha anterior al alta y la muestra en su mes',
    (tester) async {
      await boot(tester, 2);
      await fill(tester);
      await tester.ensureVisible(field('Fecha del movimiento'));
      await tester.enterText(field('Fecha del movimiento'), '30/09/2026');
      await press(tester, find.text('Guardar movimiento'));
      expect(movements.stored.single.details.date, DateTime(2026, 9, 30));
      final credit = movements.snapshot.accounts.singleWhere((a) => a.id == 2);
      expect(credit.currentBalance.minorUnits, 11250);
      expect(credit.details.openingDate, DateTime(2026, 10, 1));
      await choose(
        tester,
        find.byType(DropdownButtonFormField<AccountPeriod>),
        'Histórico',
      );
      await choose(
        tester,
        find.byKey(const ValueKey('history-month-2026-11')),
        'Septiembre',
      );
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
