import '../../support/movement_details.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';
import '../../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> choose(WidgetTester tester, Finder dropdown, String label) async {
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Guardar movimiento'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Guardar movimiento'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository movements;
  setUp(() async {
    accounts = FakeAccountRepository();
    for (final entry in [
      ('Banco', AccountType.bank, 100000),
      ('Efectivo', AccountType.cash, 1000),
      ('Crédito', AccountType.creditCard, 5000),
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: entry.$1,
          type: entry.$2,
          openingBalance: Money(entry.$3, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    movements = FakeMovementRepository(accounts);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
  }

  for (final entry in [('Banco · GTQ', 1, 98750), ('Crédito · GTQ', 3, 6250)]) {
    testWidgets('Registra compra desde ${entry.$1} y actualiza Cuentas', (
      tester,
    ) async {
      await open(tester);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>).first,
        entry.$1,
      );
      await tester.ensureVisible(field('Descripción'));
      await tester.enterText(field('Descripción'), 'Compra sintética');
      await tester.ensureVisible(field('Importe'));
      await tester.enterText(field('Importe'), '12.50');
      await submit(tester);
      expect(find.text('Movimiento guardado'), findsOneWidget);
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(find.text('GTQ 12.50'), findsOneWidget);
      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();
      expect(
        find.text(Money(entry.$3, Currency.gtq).formatted),
        findsOneWidget,
      );
      expect(
        movements.snapshot.accounts
            .firstWhere((a) => a.id == entry.$2)
            .currentBalance
            .minorUnits,
        entry.$3,
      );
    });
  }

  testWidgets(
    'Un pago registra una operación vinculada y actualiza origen y deuda',
    (tester) async {
      await open(tester);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<MovementType>),
        'Pago de tarjeta',
      );
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>).first,
        'Banco · GTQ',
      );
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>).last,
        'Crédito',
      );
      await tester.ensureVisible(field('Descripción'));
      await tester.enterText(field('Descripción'), 'Pago sintético');
      await tester.ensureVisible(field('Importe'));
      await tester.enterText(field('Importe'), '20');
      await submit(tester);
      await openMovementDetails(tester, 1);
      expect(find.text('Cuenta: Banco'), findsOneWidget);
      expect(find.text('Destino: Crédito'), findsOneWidget);
      expect(
        find.text('Transferencia · No suma ingresos ni gastos'),
        findsOneWidget,
      );
      expect(movements.stored.single.details.isExpense, isFalse);
      await closeMovementDetails(tester);
      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();
      expect(find.text('GTQ 980.00'), findsOneWidget);
      expect(find.text('GTQ 30.00'), findsOneWidget);
    },
  );

  testWidgets(
    'El error de escritura conserva el formulario y permite reintentar',
    (tester) async {
      movements.failSave = true;
      await open(tester);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>),
        'Banco · GTQ',
      );
      await tester.ensureVisible(field('Descripción'));
      await tester.enterText(field('Descripción'), 'Compra sintética');
      await tester.ensureVisible(field('Importe'));
      await tester.enterText(field('Importe'), '1.29');
      await submit(tester);
      expect(
        find.textContaining('No se pudo guardar el movimiento'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field('Importe')).controller!.text,
        '1.29',
      );
      expect(movements.stored, isEmpty);
      movements.failSave = false;
      await submit(tester);
      expect(movements.stored, hasLength(1));
    },
  );

  testWidgets('Cancelar el formulario no guarda un movimiento', (tester) async {
    await open(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo movimiento'), findsNothing);
    expect(movements.stored, isEmpty);
  });

  testWidgets('Guardar exige seleccionar una cuenta y muestra el error', (
    tester,
  ) async {
    await open(tester);
    await submit(tester);
    expect(find.text('Selecciona una cuenta.'), findsOneWidget);
    expect(movements.createCalls, 0);
  });

  testWidgets('Bloquea guardar y volver durante una escritura pendiente', (
    tester,
  ) async {
    movements.saveGate = Completer<void>();
    await open(tester);
    await choose(
      tester,
      find.byType(DropdownButtonFormField<int>),
      'Banco · GTQ',
    );
    await tester.ensureVisible(field('Descripción'));
    await tester.enterText(field('Descripción'), 'Compra sintética');
    await tester.ensureVisible(field('Importe'));
    await tester.enterText(field('Importe'), '1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar movimiento'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardando…'))
          .onPressed,
      isNull,
    );
    await Navigator.of(tester.element(find.text('Nuevo movimiento')))
        .maybePop();
    await tester.pump();
    expect(find.text('Nuevo movimiento'), findsOneWidget);
    movements.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(movements.stored, hasLength(1));
  });

  testWidgets('Permite registrar a 320 px con teclado y texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    await choose(
      tester,
      find.byType(DropdownButtonFormField<int>),
      'Banco · GTQ',
    );
    await tester.ensureVisible(field('Descripción'));
    await tester.enterText(field('Descripción'), 'Compra sintética');
    await tester.ensureVisible(field('Importe'));
    await tester.enterText(field('Importe'), '0,29');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await submit(tester);
    expect(movements.stored.single.details.amount.minorUnits, 29);
    expect(tester.takeException(), isNull);
  });
}
