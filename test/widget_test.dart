import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';
import 'support/navigation.dart';

void main() {
  testWidgets(
    'Navega Inicio Cuentas Ajustes sin Movimientos ni Planificación',
    (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(nav.destinations.map((d) => (d as NavigationDestination).label), [
        'Inicio',
        'Cuentas',
        'Ajustes',
      ]);
      for (final entry in [
        ('Cuentas', 'Aquí comenzará tu organización'),
        ('Ajustes', 'Tema de la app'),
        ('Inicio', 'Resumen de deudas'),
      ]) {
        await selectAppSection(tester, entry.$1);
        expect(find.text(entry.$2), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Inicio permite abrir Cuentas y el historial general secundario',
    (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      await openHistory(tester);
      expect(find.text('Tu historial empieza aquí'), findsOneWidget);
      await tester.tap(find.text('Ir a Cuentas'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.byKey(const ValueKey('account-admin')), findsNothing);
      await selectAppSection(tester, 'Inicio');
      await tester.tap(find.text('Ver cuentas'));
      await tester.pumpAndSettle();
      expect(find.text('Aquí comenzará tu organización'), findsOneWidget);
    },
  );
  testWidgets('Usa navegación lateral de tres secciones en escritorio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await selectAppSection(tester, 'Ajustes');
    expect(find.text('Categorías'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Tres secciones y los catálogos caben a 320 px con texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      for (final label in ['Cuentas', 'Ajustes', 'Inicio']) {
        await selectAppSection(tester, label);
        expect(tester.takeException(), isNull);
      }
      await openCategoryCatalog(tester);
      expect(find.text('Agregar categoría'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
