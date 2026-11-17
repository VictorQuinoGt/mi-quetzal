import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/models/app_appearance.dart';
import 'package:mi_quetzal/app/appearance_view_model.dart';

import '../support/fake_account_repository.dart';
import '../support/fake_movement_repository.dart';
import '../support/navigation.dart';
import '../support/test_app.dart';
import '../support/fake_settings_repository.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Finder dropdown() => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField<int> &&
      w.decoration.labelText == 'Categoría (opcional)',
);
Future<void> press(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository ledger;
  setUp(() async {
    accounts = FakeAccountRepository();
    for (final type in [AccountType.bank, AccountType.creditCard]) {
      await accounts.createAccount(
        AccountDetails(
          name: 'Cuenta sintética ${type.name}',
          type: type,
          openingBalance: Money(10000, Currency.gtq),
          openingDate: DateTime(2026, 1, 1),
        ),
      );
    }
    ledger = FakeMovementRepository(accounts);
  });

  testWidgets(
    'Inicio se actualiza tras guardar, conserva saldos a favor y el historial no altera los totales',
    (tester) async {
      await accounts.createAccount(
        AccountDetails(
          name: 'Tarjeta a favor sintética',
          type: AccountType.creditCard,
          openingBalance: Money(0, Currency.gtq),
          openingDate: DateTime(2026, 1, 1),
        ),
      );
      await ledger.createMovement(
        MovementDetails(
          type: MovementType.creditPayment,
          accountId: 3,
          paymentFunding: PaymentFunding.externalCash,
          amount: Money(10000, Currency.gtq),
          date: DateTime(2026, 11, 1),
          description: 'Abono sintético',
        ),
      );
      await tester.pumpWidget(testApp(repository: accounts, movements: ledger));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('total-debt-gtq'))).data,
        'GTQ 100.00',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('total-credit-gtq')))
            .data,
        'GTQ 100.00',
      );
      await openAccountMovement(tester, 2);
      await tester.enterText(
        field('Descripción'),
        'Compra posterior sintética',
      );
      await tester.ensureVisible(field('Importe'));
      await tester.enterText(field('Importe'), '12.50');
      await press(tester, 'Guardar movimiento');
      await selectAppSection(tester, 'Inicio');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('total-debt-gtq'))).data,
        'GTQ 112.50',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('total-credit-gtq')))
            .data,
        'GTQ 100.00',
      );
      await openHistory(tester, filters: false);
      expect(find.text('Registrar'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.enterText(
        field('Buscar en descripción'),
        'Sin coincidencias',
      );
      await tester.pumpAndSettle();
      await selectAppSection(tester, 'Inicio');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('total-debt-gtq'))).data,
        'GTQ 112.50',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ajustes permite cambiar apariencia y los catálogos están separados',
    (tester) async {
      final appearance = AppearanceViewModel(FakeSettingsRepository());
      addTearDown(appearance.dispose);
      await tester.pumpWidget(
        testApp(
          repository: accounts,
          movements: ledger,
          appearance: appearance,
        ),
      );
      await tester.pumpAndSettle();
      await selectAppSection(tester, 'Ajustes');
      await tester.tap(find.byType(DropdownButtonFormField<AppAppearance>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oscuro').last);
      await tester.pumpAndSettle();
      expect(appearance.appearance, AppAppearance.dark);
      await tester.tap(find.text('Categorías'));
      await tester.pumpAndSettle();
      expect(find.text('Entidades financieras'), findsNothing);
      await selectAppSection(tester, 'Ajustes');
      await tester.tap(find.text('Entidades financieras'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar categoría'), findsNothing);
      expect(find.text('Agregar entidad financiera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final entry in [
    ('Gasto', 2, CategoryKind.expense),
    ('Pago', 2, CategoryKind.payment),
    ('Ingreso', 1, CategoryKind.income),
  ]) {
    testWidgets(
      'Agrega categoría ${entry.$1}, la selecciona y conserva importe descripción fecha y cuenta',
      (tester) async {
        await tester.pumpWidget(
          testApp(repository: accounts, movements: ledger),
        );
        await tester.pumpAndSettle();
        await openAccountMovement(tester, entry.$2, operation: entry.$1);
        await tester.enterText(field('Descripción'), 'Operación sintética');
        await tester.ensureVisible(field('Importe'));
        await tester.enterText(field('Importe'), '12.50');
        await tester.ensureVisible(field('Fecha del movimiento'));
        await tester.enterText(field('Fecha del movimiento'), '10/11/2026');
        await press(tester, 'Agregar categoría');
        expect(find.text('Uso: ${entry.$1}'), findsOneWidget);
        expect(
          find.byType(DropdownButtonFormField<CategoryKind>),
          findsNothing,
        );
        await press(tester, 'Agregar');
        expect(ledger.categories, isEmpty);
        await tester.enterText(
          field('Nombre de categoría'),
          'Categoría sintética',
        );
        ledger.failSave = true;
        await press(tester, 'Agregar');
        expect(
          find.textContaining('No se pudo crear la categoría'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(field('Nombre de categoría'))
              .controller!
              .text,
          'Categoría sintética',
        );
        ledger.failSave = false;
        await press(tester, 'Agregar');
        expect(
          tester.widget<DropdownButtonFormField<int>>(dropdown()).initialValue,
          ledger.categories.single.id,
        );
        expect(ledger.categories.single.details.kind, entry.$3);
        expect(
          tester.widget<TextField>(field('Descripción')).controller!.text,
          'Operación sintética',
        );
        expect(
          tester.widget<TextField>(field('Importe')).controller!.text,
          '12.50',
        );
        expect(
          tester
              .widget<TextField>(field('Fecha del movimiento'))
              .controller!
              .text,
          '10/11/2026',
        );
        if (entry.$1 == 'Pago') {
          final origin = find.byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<int> &&
                w.decoration.labelText == 'Cuenta de origen',
          );
          await tester.ensureVisible(origin);
          await tester.tap(origin);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cuenta sintética bank · GTQ').last);
          await tester.pumpAndSettle();
        }
        await press(tester, 'Guardar movimiento');
        expect(
          ledger.stored.single.details.categoryId,
          ledger.categories.single.id,
        );
        expect(ledger.stored.single.details.amount.minorUnits, 1250);
        expect(ledger.stored.single.details.date, DateTime(2026, 11, 10));
        await openCategoryCatalog(tester);
        expect(find.text('Categoría sintética'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Alta bloquea doble envío y volver, y cancelar movimiento conserva la categoría sin crear operaciones',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(testApp(repository: accounts, movements: ledger));
      await tester.pumpAndSettle();
      await openAccountMovement(tester, 2);
      await press(tester, 'Agregar categoría');
      await tester.enterText(
        field('Nombre de categoría'),
        'Categoría persistida',
      );
      ledger.saveGate = Completer<void>();
      await tester.tap(find.text('Agregar'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(FilledButton, 'Guardando…'),
              ),
            )
            .onPressed,
        isNull,
      );
      await Navigator.of(tester.element(find.byType(AlertDialog))).maybePop();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      ledger.saveGate!.complete();
      await tester.pumpAndSettle();
      ledger.saveGate = null;
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(ledger.stored, isEmpty);
      await openCategoryCatalog(tester);
      expect(find.text('Categoría persistida'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
