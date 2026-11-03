import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/financial_institution.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';

import '../support/fake_account_repository.dart';
import '../support/fake_movement_repository.dart';
import '../support/movement_details.dart';
import '../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> press(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, Finder target, String value) async {
  await press(tester, target);
  await tester.tap(find.text(value).last);
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
        openingBalance: Money(10000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await accounts.createAccount(
      AccountDetails(
        name: 'Crédito sintético',
        type: AccountType.creditCard,
        openingBalance: Money(500, Currency.gtq),
        secondaryOpeningBalance: Money(2000, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito sintético', accountId: 1),
    );
    movements = FakeMovementRepository(accounts);
  });
  Future<void> boot(WidgetTester tester, {String section = 'Cuentas'}) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(section));
    await tester.pumpAndSettle();
  }

  Future<void> record() async {
    await movements.createCategory(
      CategoryDetails(name: 'Gasto sintético', kind: CategoryKind.expense),
    );
    await movements.createMovement(
      MovementDetails(
        type: MovementType.expense,
        accountId: 1,
        debitCardId: 1,
        categoryId: 1,
        amount: Money(125, Currency.gtq),
        date: DateTime(2026, 11, 1),
        description: 'Compra sintética',
      ),
    );
  }

  testWidgets(
    'Crea catálogo en Categorías y asigna entidad y terminación sin alterar saldos',
    (tester) async {
      await record();
      await boot(tester);
      await press(tester, find.text('Entidades financieras'));
      await tester.enterText(
        field('Nombre de entidad financiera'),
        'Entidad sintética',
      );
      await press(tester, find.text('Agregar entidad financiera'));
      expect(movements.categories, hasLength(1));
      expect(
        accounts.financialInstitutions.single.details.name,
        'Entidad sintética',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await press(tester, find.byTooltip('Editar Banco sintético'));
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>),
        'Entidad sintética',
      );
      await tester.enterText(field('Terminación (últimos 4 dígitos)'), '0042');
      await press(tester, find.text('Guardar cuenta'));
      expect(
        find.text('Entidad financiera: Entidad sintética'),
        findsNWidgets(2),
      );
      expect(find.text('Cuenta bancaria · •••• 0042'), findsOneWidget);
      expect(find.text('GTQ 98.75'), findsNWidgets(2));
      expect(find.text('Deuda actual'), findsNothing);
      expect(find.textContaining('inicial:'), findsNothing);
      expect(find.textContaining('Vinculada a:'), findsNothing);
      expect(find.textContaining('Comparte el saldo'), findsNothing);
      expect(find.textContaining('Los saldos se calculan'), findsNothing);
      await press(tester, find.byTooltip('Editar Crédito sintético'));
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>),
        'Entidad sintética',
      );
      await press(tester, find.text('Guardar cuenta'));
      expect(
        find.text('Entidad financiera: Entidad sintética'),
        findsNWidgets(3),
      );
      expect(find.text('USD 20.00'), findsOneWidget);
      expect(movements.stored.single.details.amount.minorUnits, 125);
      await tester.pumpWidget(const SizedBox());
      await boot(tester);
      expect(find.text('Cuenta bancaria · •••• 0042'), findsOneWidget);
      expect(
        find.text('Entidad financiera: Entidad sintética'),
        findsNWidgets(3),
      );
    },
  );
  testWidgets(
    'Débito puede seleccionar entidad explícita del catálogo y conserva el banco',
    (tester) async {
      await movements.createFinancialInstitution(
        FinancialInstitutionDetails(name: 'Entidad de tarjeta sintética'),
      );
      await boot(tester);
      await press(tester, find.byTooltip('Editar Débito sintético'));
      await choose(
        tester,
        find.byKey(const ValueKey('debit-institution')),
        'Entidad de tarjeta sintética',
      );
      await press(tester, find.text('Guardar tarjeta'));
      expect(
        find.text('Entidad financiera: Entidad de tarjeta sintética'),
        findsOneWidget,
      );
      expect(accounts.cards.single.details.accountId, 1);
      expect(accounts.cards.single.details.financialInstitutionId, 1);
    },
  );
  testWidgets(
    'Estado de cuenta muestra datos compactos y pregunta abre detalle sin escribir',
    (tester) async {
      await record();
      await boot(tester, section: 'Movimientos');
      expect(find.text('Estado de cuenta'), findsOneWidget);
      expect(find.text('Compra sintética'), findsOneWidget);
      expect(find.text('GTQ 1.25'), findsOneWidget);
      expect(find.text('Categorizar'), findsNothing);
      expect(find.text('Devolver'), findsNothing);
      expect(find.text('Categoría: Gasto sintético'), findsNothing);
      final date = MaterialLocalizations.of(
        tester.element(find.text('Estado de cuenta')),
      ).formatMediumDate(DateTime(2026, 11, 1));
      expect(find.text(date), findsOneWidget);
      await openMovementDetails(tester, 1);
      expect(find.text('Compra o gasto'), findsOneWidget);
      expect(find.text('Categoría: Gasto sintético'), findsOneWidget);
      expect(find.text('Cuenta: Banco sintético'), findsOneWidget);
      expect(find.text('Débito: Débito sintético'), findsOneWidget);
      expect(find.text('Categorizar'), findsOneWidget);
      expect(find.text('Devolver'), findsOneWidget);
      expect(movements.createCalls, 1);
      expect(movements.assignCategoryCalls, 0);
      await closeMovementDetails(tester);
      expect(find.text('Estado de cuenta'), findsOneWidget);
    },
  );
  testWidgets('Dos cuentas del mismo banco se distinguen por su terminación', (
    tester,
  ) async {
    accounts.stored.clear();
    accounts.cards.clear();
    for (final tail in ['0042', '0043']) {
      await accounts.createAccount(
        AccountDetails(
          name: 'Banco sintético',
          type: AccountType.bank,
          lastFour: tail,
          openingBalance: Money(100, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
    }
    await boot(tester);
    expect(find.text('Cuenta bancaria · •••• 0042'), findsOneWidget);
    expect(find.text('Cuenta bancaria · •••• 0043'), findsOneWidget);
    expect(accounts.stored, hasLength(2));
  });
  testWidgets(
    'Catálogo valida nombre, conserva formulario al fallar y bloquea envío y volver',
    (tester) async {
      await boot(tester);
      await press(tester, find.text('Entidades financieras'));
      await press(tester, find.text('Agregar entidad financiera'));
      expect(
        find.textContaining('nombre de entidad de 1 a 60'),
        findsOneWidget,
      );
      expect(movements.createInstitutionCalls, 0);
      await tester.enterText(
        field('Nombre de entidad financiera'),
        'Entidad sintética',
      );
      movements.failSave = true;
      await press(tester, find.text('Agregar entidad financiera'));
      expect(
        find.textContaining('No se pudo crear la entidad financiera'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(field('Nombre de entidad financiera'))
            .controller!
            .text,
        'Entidad sintética',
      );
      movements.failSave = false;
      movements.saveGate = Completer<void>();
      await tester.tap(find.text('Agregar entidad financiera'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardando entidad…'),
            )
            .onPressed,
        isNull,
      );
      await Navigator.of(tester.element(find.text('Categorías'))).maybePop();
      await tester.pump();
      expect(find.text('Nombre de entidad financiera'), findsOneWidget);
      movements.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(accounts.financialInstitutions, hasLength(1));
    },
  );
  testWidgets('Lista y detalle se adaptan a 320 px con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await record();
    await boot(tester, section: 'Movimientos');
    await openMovementDetails(tester, 1);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Devolver'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
