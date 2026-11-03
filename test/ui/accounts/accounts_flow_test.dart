import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';

import '../../support/fake_account_repository.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> openForm(
  WidgetTester tester,
  FakeAccountRepository repository,
) async {
  await tester.pumpWidget(testApp(repository: repository));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Explorar mis cuentas'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Explorar mis cuentas'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Nueva cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nueva cuenta'));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Guardar cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Guardar cuenta'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Guarda una cuenta y la recupera al reconstruir la aplicación', (
    tester,
  ) async {
    final repository = FakeAccountRepository();
    await openForm(tester, repository);
    await tester.enterText(field('Alias'), 'Banco de prueba');
    await tester.enterText(field('Saldo inicial'), '1234.56');
    await submit(tester);
    expect(find.text('Cuenta guardada'), findsOneWidget);
    expect(find.text('Banco de prueba'), findsOneWidget);
    expect(find.text('GTQ 1,234.56'), findsOneWidget);
    expect(repository.stored, hasLength(1));

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(testApp(repository: repository));
    await tester.tap(find.text('Explorar mis cuentas'));
    await tester.pumpAndSettle();
    expect(find.text('Banco de prueba'), findsOneWidget);
    expect(find.text('GTQ 1,234.56'), findsOneWidget);
  });

  testWidgets('Distingue deuda y límite en una tarjeta USD', (tester) async {
    final repository = FakeAccountRepository();
    await openForm(tester, repository);
    await tester.enterText(field('Alias'), 'Crédito de prueba');
    await tester.tap(find.byType(DropdownButtonFormField<AccountType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjeta de crédito').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Currency>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD · Dólares').last);
    await tester.pumpAndSettle();
    await tester.enterText(field('Deuda inicial'), '125.20');
    await tester.ensureVisible(field('Límite de crédito (opcional)'));
    await tester.enterText(field('Límite de crédito (opcional)'), '1000');
    await tester.ensureVisible(field('Últimos 4 dígitos (opcional)'));
    await tester.enterText(field('Últimos 4 dígitos (opcional)'), '0042');
    await submit(tester);

    expect(find.text('Saldo actual'), findsOneWidget);
    expect(find.text('USD 125.20'), findsOneWidget);
    expect(find.text('Límite de crédito: USD 1,000.00'), findsOneWidget);
    expect(find.textContaining('•••• 0042'), findsOneWidget);
    expect(
      repository.stored.single.details.openingBalance.currency,
      Currency.usd,
    );
  });

  testWidgets('Conserva campos después de un fallo y permite reintentar', (
    tester,
  ) async {
    final repository = FakeAccountRepository()..failSave = true;
    await openForm(tester, repository);
    await tester.enterText(field('Alias'), 'Cuenta de prueba');
    await tester.enterText(field('Saldo inicial'), '10.01');
    await submit(tester);
    expect(find.textContaining('No se pudo guardar la cuenta'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('Alias')).controller!.text,
      'Cuenta de prueba',
    );
    expect(repository.stored, isEmpty);
    repository.failSave = false;
    await submit(tester);
    expect(repository.stored, hasLength(1));
    expect(find.text('GTQ 10.01'), findsOneWidget);
  });

  testWidgets(
    'Desactiva guardar y volver mientras hay una escritura pendiente',
    (tester) async {
      final repository = FakeAccountRepository()..saveGate = Completer<void>();
      await openForm(tester, repository);
      await tester.enterText(field('Alias'), 'Cuenta de prueba');
      await tester.enterText(field('Saldo inicial'), '0');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cuenta'));
      await tester.pump();
      expect(find.text('Guardando…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardando…'),
            )
            .onPressed,
        isNull,
      );
      final context = tester.element(find.text('Nueva cuenta'));
      await Navigator.of(context).maybePop();
      await tester.pump();
      expect(find.text('Nueva cuenta'), findsOneWidget);
      expect(repository.createCalls, 1);
      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('GTQ 0.00'), findsOneWidget);
    },
  );

  testWidgets('Reintenta una carga fallida y muestra el estado vacío', (
    tester,
  ) async {
    final repository = FakeAccountRepository()..failLoad = true;
    await tester.pumpWidget(testApp(repository: repository));
    await tester.tap(find.text('Explorar mis cuentas'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se pudieron cargar tus cuentas'),
      findsOneWidget,
    );
    repository.failLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cuenta'), findsOneWidget);
  });

  testWidgets('El formulario funciona a 320 px con teclado y texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = FakeAccountRepository();
    await openForm(tester, repository);
    await tester.enterText(field('Alias'), 'Cuenta de prueba');
    await tester.ensureVisible(field('Saldo inicial'));
    await tester.enterText(field('Saldo inicial'), '15,25');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await submit(tester);
    expect(repository.stored.single.details.openingBalance.minorUnits, 1525);
    expect(tester.takeException(), isNull);
  });
}
