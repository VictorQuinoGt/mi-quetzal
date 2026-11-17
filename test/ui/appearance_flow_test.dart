import '../support/navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/app/appearance_view_model.dart';
import 'package:mi_quetzal/domain/models/app_appearance.dart';

import '../support/fake_settings_repository.dart';
import '../support/test_app.dart';

Brightness brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(NavigationBar))).brightness;

Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Apariencia'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(CheckedPopupMenuItem<AppAppearance>, label),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Restaura oscuro desde el primer cuadro y adapta la navegación lateral',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeSettingsRepository()
        ..appearance = AppAppearance.dark;
      final vm = AppearanceViewModel(repository);
      addTearDown(vm.dispose);
      await vm.load();
      await tester.pumpWidget(testApp(appearance: vm));
      expect(
        Theme.of(tester.element(find.byType(NavigationRail))).brightness,
        Brightness.dark,
      );
      await tester.pumpAndSettle();
      await choose(tester, 'Claro');
      expect(
        Theme.of(tester.element(find.byType(NavigationRail))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sistema sigue Android y la selección manual tiene prioridad', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final repository = FakeSettingsRepository();
    final vm = AppearanceViewModel(repository);
    addTearDown(vm.dispose);
    await tester.pumpWidget(testApp(appearance: vm));
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.dark);
    await choose(tester, 'Claro');
    expect(brightness(tester), Brightness.light);
    expect(repository.appearance, AppAppearance.light);
    await choose(tester, 'Oscuro');
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.dark);
    await choose(tester, 'Sistema');
    expect(brightness(tester), Brightness.light);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(brightness(tester), Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cambiar apariencia conserva sección y formulario abierto', (
    tester,
  ) async {
    final vm = AppearanceViewModel(FakeSettingsRepository());
    addTearDown(vm.dispose);
    await tester.pumpWidget(testApp(appearance: vm));
    await tester.pumpAndSettle();
    await selectAppSection(tester, 'Cuentas');
    await tester.pumpAndSettle();
    await choose(tester, 'Oscuro');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.tap(find.text('Agregar cuenta'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'Cuenta sintética');
    await vm.select(AppAppearance.light);
    await tester.pumpAndSettle();
    expect(find.text('Cuenta sintética'), findsOneWidget);
    expect(Theme.of(tester.element(field)).brightness, Brightness.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Un fallo al persistir muestra el error y restaura la apariencia',
    (tester) async {
      final repository = FakeSettingsRepository()..failWrite = true;
      final vm = AppearanceViewModel(repository);
      addTearDown(vm.dispose);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(testApp(appearance: vm));
      await tester.pumpAndSettle();
      await choose(tester, 'Oscuro');
      expect(brightness(tester), Brightness.light);
      expect(
        find.text('No se pudo guardar la apariencia. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Las secciones en oscuro caben en 320 px con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final vm = AppearanceViewModel(FakeSettingsRepository());
    addTearDown(vm.dispose);
    await vm.select(AppAppearance.dark);
    await tester.pumpWidget(testApp(appearance: vm));
    await tester.pumpAndSettle();
    for (final label in ['Cuentas', 'Ajustes', 'Inicio']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.dark);
      expect(tester.takeException(), isNull);
    }
    await choose(tester, 'Claro');
    expect(brightness(tester), Brightness.light);
    expect(tester.takeException(), isNull);
  });
}
