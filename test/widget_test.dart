import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('Permite recorrer las cuatro secciones en móvil', (tester) async {
    await tester.pumpWidget(testApp());
    expect(find.text('Tu dinero,\ncon claridad.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final entry in [
      ('Movimientos', 'Tu historial empieza aquí'),
      ('Cuentas', 'Aquí comenzará tu organización'),
      ('Planificación', 'Haz espacio para tus próximos planes'),
      ('Inicio', 'Tu dinero,\ncon claridad.'),
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(entry.$1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('El acceso desde Inicio selecciona Cuentas', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.tap(find.text('Explorar mis cuentas'));
    await tester.pumpAndSettle();
    expect(find.text('Aquí comenzará tu organización'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('Registrar sin cuentas conduce al alta de cuentas', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(find.text('Primero agrega una cuenta'), findsOneWidget);
    expect(find.text('Aquí comenzará tu organización'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('El estado vacío de Movimientos enlaza a Cuentas', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ir a Cuentas'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cuenta'), findsOneWidget);
  });

  testWidgets('Usa navegación lateral en escritorio', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Planificación'));
    await tester.pumpAndSettle();
    expect(find.text('Tu planificación'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Las secciones caben con texto ampliado en 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(testApp());
    for (final label in ['Movimientos', 'Cuentas', 'Planificación', 'Inicio']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(find.text('Aquí comenzará tu organización'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
