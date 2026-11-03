import '../support/movement_details.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';

import '../support/fake_account_repository.dart';
import '../support/fake_movement_repository.dart';
import '../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> press(WidgetTester tester, String label) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
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
        openingBalance: Money(1000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    movements = FakeMovementRepository(accounts);
    await movements.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: 1,
        amount: Money(500, Currency.gtq),
        date: DateTime(2026, 11, 1),
        description: 'Compra sintética',
      ),
    );
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();
    await openMovementDetails(tester, 1);
    await press(tester, 'Devolver');
  }

  Future<void> fill(WidgetTester tester, String amount) async {
    await tester.enterText(
      field('Descripción de la devolución'),
      'Reembolso sintético',
    );
    await tester.enterText(field('Importe a devolver'), amount);
  }

  testWidgets(
    'Devuelve parcialmente, muestra vínculo y filtra sin alterar resumen ni saldo',
    (tester) async {
      await open(tester);
      expect(find.text('Pendiente de devolver: GTQ 5.00'), findsOneWidget);
      await fill(tester, '1.25');
      await press(tester, 'Guardar devolución');
      expect(movements.stored, hasLength(2));
      expect(movements.stored.last.details.originalMovementId, 1);
      expect(movements.stored.first.details.amount.minorUnits, 500);
      expect(find.text('Pendiente de devolver: GTQ 3.75'), findsOneWidget);
      await closeMovementDetails(tester);
      await openMovementDetails(tester, 2);
      expect(find.text('Compra original: Compra sintética'), findsOneWidget);
      await closeMovementDetails(tester);
      final typeFilter = find.byType(DropdownButtonFormField<MovementType>);
      await tester.ensureVisible(typeFilter);
      await tester.pumpAndSettle();
      await tester.tap(typeFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devolución').last);
      await tester.pumpAndSettle();
      expect(find.text('1 de 2 movimientos'), findsOneWidget);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('GTQ 3.75'), findsNWidgets(2));
      expect(find.text('GTQ -3.75'), findsOneWidget);
      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();
      expect(find.text('GTQ 6.25'), findsOneWidget);
    },
  );
  testWidgets('Exceso no escribe; fallo conserva campos y permite reintentar', (
    tester,
  ) async {
    await open(tester);
    await fill(tester, '5.01');
    await press(tester, 'Guardar devolución');
    expect(find.textContaining('supera el pendiente'), findsOneWidget);
    expect(movements.createCalls, 1);
    await tester.enterText(field('Importe a devolver'), '2.00');
    movements.failSave = true;
    await press(tester, 'Guardar devolución');
    expect(
      find.textContaining('No se pudo guardar el movimiento'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(field('Importe a devolver')).controller!.text,
      '2.00',
    );
    expect(
      tester
          .widget<TextField>(field('Descripción de la devolución'))
          .controller!
          .text,
      'Reembolso sintético',
    );
    movements.failSave = false;
    await press(tester, 'Guardar devolución');
    expect(movements.stored, hasLength(2));
    expect(movements.snapshot.accounts.single.currentBalance.minorUnits, 700);
  });
  testWidgets(
    'Devolución completa cierra el pendiente y no ofrece devolver de nuevo',
    (tester) async {
      await open(tester);
      await fill(tester, '5');
      await press(tester, 'Guardar devolución');
      expect(find.text('Compra devuelta por completo'), findsOneWidget);
      expect(find.text('Devolver'), findsNothing);
      expect(
        movements.snapshot.accounts.single.currentBalance.minorUnits,
        1000,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        testApp(repository: accounts, movements: movements),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Movimientos'));
      await tester.pumpAndSettle();
      expect(find.text('Reembolso sintético'), findsOneWidget);
      await openMovementDetails(tester, 1);
      expect(find.text('Compra devuelta por completo'), findsOneWidget);
    },
  );
  testWidgets('Escritura bloquea doble envío y navegación hacia atrás', (
    tester,
  ) async {
    await open(tester);
    await fill(tester, '1');
    movements.saveGate = Completer<void>();
    await tester.ensureVisible(find.text('Guardar devolución'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar devolución'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardando…'))
          .onPressed,
      isNull,
    );
    await Navigator.of(tester.element(find.text('Nueva devolución')))
        .maybePop();
    await tester.pump();
    expect(find.text('Nueva devolución'), findsOneWidget);
    movements.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(movements.createCalls, 2);
    expect(movements.stored, hasLength(2));
  });
  testWidgets(
    'Formulario a 320 px con texto ampliado y teclado permite cancelar sin cambios',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await fill(tester, '1.25');
      await tester.ensureVisible(find.text('Guardar devolución'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(movements.stored, hasLength(1));
    },
  );
}
