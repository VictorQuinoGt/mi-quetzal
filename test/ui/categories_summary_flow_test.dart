import '../support/movement_details.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';

import '../support/fake_account_repository.dart';
import '../support/fake_movement_repository.dart';
import '../support/test_app.dart';

Finder field(String name) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == name,
);
Future<void> press(WidgetTester tester, String text) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, Finder dropdown, String text) async {
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository movements;
  setUp(() async {
    accounts = FakeAccountRepository();
    for (final entry in [
      ('Banco', AccountType.bank, Currency.gtq),
      ('Crédito', AccountType.creditCard, Currency.gtq),
      ('Banco USD', AccountType.bank, Currency.usd),
    ]) {
      await accounts.createAccount(
        AccountDetails(
          name: entry.$1,
          type: entry.$2,
          openingBalance: Money(
            entry.$2 == AccountType.bank ? 10000 : 0,
            entry.$3,
          ),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    movements = FakeMovementRepository(accounts);
  });
  Future<void> boot(WidgetTester tester, {bool history = true}) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    if (history) {
      await tester.tap(find.text('Movimientos'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> categories() async {
    await movements.createCategory(
      CategoryDetails(name: 'Alimentos sintéticos', kind: CategoryKind.expense),
    );
    await movements.createCategory(
      CategoryDetails(name: 'Salario sintético', kind: CategoryKind.income),
    );
  }

  Future<void> record(
    MovementType type,
    int source,
    int amount,
    String description, {
    int? other,
    int? category,
    Currency currency = Currency.gtq,
    DateTime? date,
  }) async {
    await movements.createMovement(
      MovementDetails(
        type: type,
        accountId: source,
        counterpartyAccountId: other,
        categoryId: category,
        amount: Money(amount, currency),
        date: date ?? DateTime(2026, 11, 2),
        description: description,
      ),
    );
  }

  testWidgets('Crea categorías propias y las recupera al reconstruir la app', (
    tester,
  ) async {
    await boot(tester);
    await press(tester, 'Categorías');
    await tester.enterText(
      field('Nombre de categoría'),
      'Alimentos sintéticos',
    );
    await press(tester, 'Crear categoría');
    expect(find.text('Categoría creada'), findsOneWidget);
    expect(movements.categories, hasLength(1));
    await tester.ensureVisible(field('Nombre de categoría'));
    await tester.enterText(field('Nombre de categoría'), 'Salario sintético');
    await choose(
      tester,
      find.byType(DropdownButtonFormField<CategoryKind>),
      'Ingreso',
    );
    await press(tester, 'Crear categoría');
    expect(movements.categories, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await boot(tester);
    await press(tester, 'Categorías');
    expect(find.text('Alimentos sintéticos'), findsOneWidget);
    expect(find.text('Salario sintético'), findsOneWidget);
  });

  testWidgets(
    'Clasifica una compra anterior y puede quitar categoría sin cambiar importe',
    (tester) async {
      await categories();
      await record(MovementType.expense, 2, 500, 'Compra anterior sintética');
      await boot(tester);
      await openMovementDetails(tester, 1);
      await press(tester, 'Categorizar');
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>),
        'Alimentos sintéticos',
      );
      await press(tester, 'Guardar categoría');
      expect(find.text('Categoría: Alimentos sintéticos'), findsOneWidget);
      expect(movements.stored.single.id, 1);
      expect(movements.snapshot.accounts[1].currentBalance.minorUnits, 500);
      await openMovementDetails(tester, 1);
      await press(tester, 'Categorizar');
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>),
        'Sin categoría',
      );
      await press(tester, 'Guardar categoría');
      expect(movements.stored.single.details.categoryId, isNull);
      expect(
        movements.stored.single.details.description,
        'Compra anterior sintética',
      );
    },
  );

  testWidgets('Registra compra categorizada y la refleja en Inicio', (
    tester,
  ) async {
    await categories();
    await boot(tester, history: false);
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    await choose(
      tester,
      find.byType(DropdownButtonFormField<int>).first,
      'Crédito · GTQ',
    );
    await tester.ensureVisible(field('Descripción'));
    await tester.enterText(
      field('Descripción'),
      'Compra categorizada sintética',
    );
    await choose(
      tester,
      find.byKey(const ValueKey('movement-category-expense')),
      'Alimentos sintéticos',
    );
    await tester.ensureVisible(field('Importe'));
    await tester.enterText(field('Importe'), '2.50');
    await press(tester, 'Guardar movimiento');
    await openMovementDetails(tester, 1);
    expect(find.text('Categoría: Alimentos sintéticos'), findsOneWidget);
    await closeMovementDetails(tester);
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Gastos del mes'), findsOneWidget);
    expect(find.text('GTQ 2.50'), findsNWidgets(2));
    expect(find.text('GTQ -2.50'), findsOneWidget);
  });

  testWidgets('Fallo al categorizar conserva selección y permite reintentar', (
    tester,
  ) async {
    await categories();
    await record(MovementType.expense, 1, 125, 'Compra sintética');
    await boot(tester);
    await openMovementDetails(tester, 1);
    await press(tester, 'Categorizar');
    await choose(
      tester,
      find.byType(DropdownButtonFormField<int>),
      'Alimentos sintéticos',
    );
    movements.failSave = true;
    await press(tester, 'Guardar categoría');
    expect(
      find.textContaining('No se pudo actualizar la categoría'),
      findsOneWidget,
    );
    expect(movements.stored.single.details.categoryId, isNull);
    movements.failSave = false;
    await press(tester, 'Guardar categoría');
    expect(movements.stored.single.details.categoryId, 1);
  });

  testWidgets('Bloquea doble guardado y volver al clasificar', (tester) async {
    await categories();
    await record(MovementType.expense, 1, 125, 'Compra sintética');
    await boot(tester);
    await openMovementDetails(tester, 1);
    await press(tester, 'Categorizar');
    await choose(
      tester,
      find.byType(DropdownButtonFormField<int>),
      'Alimentos sintéticos',
    );
    movements.saveGate = Completer<void>();
    await tester.ensureVisible(find.text('Guardar categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar categoría'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardando…'))
          .onPressed,
      isNull,
    );
    await Navigator.of(tester.element(find.text('Categorizar movimiento')))
        .maybePop();
    await tester.pump();
    expect(find.text('Categorizar movimiento'), findsOneWidget);
    movements.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(movements.assignCategoryCalls, 1);
  });

  testWidgets(
    'Filtra categoría y sin categoría y conserva el resumen mensual',
    (tester) async {
      await categories();
      await record(
        MovementType.expense,
        1,
        100,
        'Compra clasificada sintética',
        category: 1,
      );
      await record(
        MovementType.expense,
        1,
        200,
        'Compra sin clasificar sintética',
      );
      await boot(tester);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<String>),
        'Alimentos sintéticos · Gasto',
      );
      expect(find.text('1 de 2 movimientos'), findsOneWidget);
      expect(find.text('Compra clasificada sintética'), findsOneWidget);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<String>),
        'Sin categoría',
      );
      expect(find.text('Compra sin clasificar sintética'), findsOneWidget);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('GTQ 3.00'), findsOneWidget);
      expect(find.text('Gastos por categoría'), findsOneWidget);
    },
  );

  testWidgets('Resumen muestra GTQ y USD, cambia de mes y excluye pagos', (
    tester,
  ) async {
    await record(MovementType.income, 1, 1000, 'Ingreso sintético');
    await record(MovementType.expense, 2, 500, 'Compra crédito sintética');
    await record(
      MovementType.creditPayment,
      1,
      200,
      'Pago sintético',
      other: 2,
    );
    await record(
      MovementType.expense,
      3,
      300,
      'Compra USD sintética',
      currency: Currency.usd,
    );
    await record(
      MovementType.expense,
      1,
      125,
      'Compra octubre sintética',
      date: DateTime(2026, 10, 31),
    );
    await boot(tester, history: false);
    expect(find.text('GTQ 5.00'), findsWidgets);
    expect(find.text('USD 3.00'), findsWidgets);
    expect(find.text('Gastos del mes'), findsNWidgets(2));
    await tester.ensureVisible(find.byTooltip('Mes anterior'));
    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pumpAndSettle();
    expect(find.text('GTQ 1.25'), findsNWidgets(2));
    expect(find.text('USD 3.00'), findsNothing);
    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Categorías y resumen funcionan a 320 px con teclado y texto ampliado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await record(MovementType.expense, 1, 125, 'Compra sintética');
      await boot(tester);
      await press(tester, 'Categorías');
      await tester.enterText(field('Nombre de categoría'), 'Gasto sintético');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await press(tester, 'Crear categoría');
      expect(movements.categories, hasLength(1));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Resumen mensual'));
      await tester.pumpAndSettle();
      expect(find.text('GTQ 1.25'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
