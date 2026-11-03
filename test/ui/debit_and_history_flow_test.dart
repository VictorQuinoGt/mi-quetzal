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
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> choose(WidgetTester tester, Finder dropdown, String text) async {
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository movements;
  setUp(() async {
    accounts = FakeAccountRepository();
    for (final entry in [
      ('Banco', AccountType.bank, Currency.gtq),
      ('Efectivo', AccountType.cash, Currency.gtq),
      ('Crédito', AccountType.creditCard, Currency.gtq),
      ('Banco USD', AccountType.bank, Currency.usd),
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: entry.$1,
          type: entry.$2,
          openingBalance: Money(
            entry.$2 == AccountType.bank ? 100000 : 0,
            entry.$3,
          ),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    movements = FakeMovementRepository(accounts);
  });

  Future<void> boot(WidgetTester tester, String section) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(section));
    await tester.pumpAndSettle();
  }

  Future<void> openLink(WidgetTester tester) async {
    await boot(tester, 'Cuentas');
    await press(tester, 'Vincular débito');
  }

  Future<void> fillCard(WidgetTester tester) async {
    await tester.enterText(field('Alias de tarjeta'), 'Débito de prueba');
    await choose(
      tester,
      find.byType(DropdownButtonFormField<int>).first,
      'Banco · GTQ',
    );
    await tester.ensureVisible(field('Últimos 4 dígitos (opcional)'));
    await tester.enterText(field('Últimos 4 dígitos (opcional)'), '0042');
  }

  Future<void> seedHistory() async {
    for (final entry in [
      (MovementType.expense, 1, null, Currency.gtq, 1000, 'Farmacia sintética'),
      (
        MovementType.transfer,
        1,
        2,
        Currency.gtq,
        5000,
        'Transferencia sintética',
      ),
      (
        MovementType.expense,
        4,
        null,
        Currency.usd,
        2500,
        'Compra USD sintética',
      ),
    ]) {
      await movements.createMovement(
        MovementDetails(
          type: entry.$1,
          accountId: entry.$2,
          counterpartyAccountId: entry.$3,
          amount: Money(entry.$5, entry.$4),
          date: DateTime(2026, 10, movements.stored.length + 2),
          description: entry.$6,
        ),
      );
    }
  }

  testWidgets(
    'Vincula débito a banco y recupera la tarjeta sin duplicar fondos',
    (tester) async {
      await openLink(tester);
      await fillCard(tester);
      await press(tester, 'Vincular tarjeta');
      expect(find.text('Tarjeta de débito vinculada'), findsOneWidget);
      expect(find.text('Débito de prueba'), findsOneWidget);
      expect(find.text('Entidad financiera: Sin especificar'), findsWidgets);
      expect(find.text('GTQ 1,000.00'), findsNWidgets(2));
      expect(accounts.stored, hasLength(4));
      await tester.pumpWidget(const SizedBox());
      await boot(tester, 'Cuentas');
      expect(find.text('Débito de prueba'), findsOneWidget);
      expect(find.text('GTQ 1,000.00'), findsNWidgets(2));
    },
  );

  testWidgets('No ofrece vinculación si falta una cuenta bancaria', (
    tester,
  ) async {
    accounts = FakeAccountRepository();
    movements = FakeMovementRepository(accounts);
    await boot(tester, 'Cuentas');
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Vincular débito'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text('Para vincular débito, primero crea una cuenta bancaria.'),
      findsOneWidget,
    );
  });

  testWidgets('Fallo al vincular conserva el formulario y permite reintentar', (
    tester,
  ) async {
    accounts.failSave = true;
    await openLink(tester);
    await fillCard(tester);
    await press(tester, 'Vincular tarjeta');
    expect(
      find.textContaining('No se pudo guardar la tarjeta'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(field('Alias de tarjeta')).controller!.text,
      'Débito de prueba',
    );
    expect(accounts.cards, isEmpty);
    accounts.failSave = false;
    await press(tester, 'Vincular tarjeta');
    expect(accounts.cards, hasLength(1));
  });

  testWidgets('Bloquea volver y reenviar durante la vinculación', (
    tester,
  ) async {
    accounts.saveGate = Completer<void>();
    await openLink(tester);
    await fillCard(tester);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vincular tarjeta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vincular tarjeta'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardando…'))
          .onPressed,
      isNull,
    );
    await Navigator.of(tester.element(find.text('Vincular tarjeta de débito')))
        .maybePop();
    await tester.pump();
    expect(find.text('Vincular tarjeta de débito'), findsOneWidget);
    accounts.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(accounts.createCardCalls, 1);
    expect(accounts.cards, hasLength(1));
  });

  testWidgets('Compra con tarjeta vinculada descuenta del banco una sola vez', (
    tester,
  ) async {
    await openLink(tester);
    await fillCard(tester);
    await press(tester, 'Vincular tarjeta');
    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    await choose(
      tester,
      find.byType(DropdownButtonFormField<int>).first,
      'Banco · GTQ',
    );
    await choose(
      tester,
      find.byType(DropdownButtonFormField<int>).last,
      'Débito de prueba · 0042',
    );
    await tester.ensureVisible(field('Descripción'));
    await tester.enterText(field('Descripción'), 'Compra con débito sintética');
    await tester.ensureVisible(field('Importe'));
    await tester.enterText(field('Importe'), '12.50');
    await press(tester, 'Guardar movimiento');
    await openMovementDetails(tester, 1);
    expect(find.text('Débito: Débito de prueba · •••• 0042'), findsOneWidget);
    await closeMovementDetails(tester);
    expect(movements.stored.single.details.accountId, 1);
    expect(movements.stored.single.details.debitCardId, 1);
    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
    expect(find.text('GTQ 987.50'), findsNWidgets(2));
    expect(movements.snapshot.accounts, hasLength(4));
  });

  testWidgets(
    'Combina filtros, mantiene ambas caras y limpia sin alterar saldos',
    (tester) async {
      await seedHistory();
      await boot(tester, 'Movimientos');
      expect(find.text('3 de 3 movimientos'), findsOneWidget);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>).first,
        'Efectivo · GTQ',
      );
      expect(find.text('1 de 3 movimientos'), findsOneWidget);
      expect(find.text('Transferencia sintética'), findsOneWidget);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<Currency>),
        'USD',
      );
      expect(
        find.text('No hay movimientos que coincidan con los filtros.'),
        findsOneWidget,
      );
      await press(tester, 'Limpiar filtros');
      await tester.ensureVisible(field('Buscar en descripción'));
      await tester.enterText(field('Buscar en descripción'), 'FARMACIA');
      await tester.pumpAndSettle();
      expect(find.text('1 de 3 movimientos'), findsOneWidget);
      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();
      expect(find.text('GTQ 940.00'), findsOneWidget);
      await tester.tap(find.text('Movimientos'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field('Buscar en descripción'))
            .controller!
            .text,
        'FARMACIA',
      );
      await press(tester, 'Limpiar filtros');
      expect(find.text('3 de 3 movimientos'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(field('Buscar en descripción'))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('Vincula a 320 px con teclado y texto ampliado', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openLink(tester);
    await fillCard(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await press(tester, 'Vincular tarjeta');
    expect(accounts.cards.single.details.lastFour, '0042');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Los filtros caben en 320 px con texto ampliado y búsqueda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await seedHistory();
    await boot(tester, 'Movimientos');
    await tester.ensureVisible(field('Buscar en descripción'));
    await tester.enterText(field('Buscar en descripción'), 'sin coincidencias');
    await tester.pumpAndSettle();
    expect(
      find.text('No hay movimientos que coincidan con los filtros.'),
      findsOneWidget,
    );
    await press(tester, 'Limpiar filtros');
    expect(find.text('3 de 3 movimientos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
