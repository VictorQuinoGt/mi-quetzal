import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/accounts/account_detail_view_model.dart';

import '../../support/account_details.dart';
import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';
import '../../support/movement_details.dart';
import '../../support/test_app.dart';

Future<void> press(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, Finder target, String label) async {
  await press(tester, target);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder field(String name) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == name,
);

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository movements;
  setUp(() async {
    accounts = FakeAccountRepository();
    await accounts.createAccount(
      AccountDetails(
        name: 'Banco elegido',
        type: AccountType.bank,
        openingBalance: Money(10000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
        lastFour: '0042',
      ),
    );
    await accounts.createAccount(
      AccountDetails(
        name: 'Crédito elegido',
        type: AccountType.creditCard,
        openingBalance: Money(500, Currency.gtq),
        secondaryOpeningBalance: Money(2000, Currency.usd),
        creditLimit: Money(10000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await accounts.createAccount(
      AccountDetails(
        name: 'Otro banco',
        type: AccountType.bank,
        openingBalance: Money(10000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    await accounts.createDebitCard(
      DebitCardDetails(name: 'Débito elegido', accountId: 1, lastFour: '0027'),
    );
    movements = FakeMovementRepository(accounts);
    for (final item in [
      (1, MovementType.expense, 125, DateTime(2026, 10, 31), 'Compra octubre'),
      (
        1,
        MovementType.income,
        1000,
        DateTime(2026, 11, 1),
        'Ingreso noviembre',
      ),
      (2, MovementType.expense, 500, DateTime(2026, 11, 1), 'Compra crédito'),
      (
        3,
        MovementType.expense,
        200,
        DateTime(2026, 11, 1),
        'Compra otra cuenta',
      ),
    ]) {
      await movements.createMovement(
        MovementDetails(
          type: item.$2,
          accountId: item.$1,
          amount: Money(item.$3, Currency.gtq),
          date: item.$4,
          description: item.$5,
        ),
      );
    }
  });
  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: movements),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuentas'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Lista compacta abre la cuenta correcta, sin lápices ni botón flotante',
    (tester) async {
      await boot(tester);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.text('Agregar cuenta'), findsOneWidget);
      expect(find.text('Vincular débito'), findsNothing);
      expect(find.text('Entidades financieras'), findsNothing);
      expect(find.textContaining('Límite de crédito:'), findsNothing);
      await openAccountDetails(tester, 1);
      expect(find.text('Banco elegido'), findsOneWidget);
      expect(find.byTooltip('Editar Banco elegido'), findsOneWidget);
      expect(find.text('Cuenta bancaria · •••• 0042'), findsOneWidget);
      expect(find.byKey(const ValueKey('movement-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('movement-3')), findsNothing);
      expect(find.byKey(const ValueKey('movement-4')), findsNothing);
      await closeAccountDetails(tester);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    },
  );
  testWidgets(
    'Período actual, anterior e histórico no reinterpreta saldo actual ni usa calendario de días',
    (tester) async {
      await boot(tester);
      await openAccountDetails(tester, 1);
      expect(find.text('GTQ 108.75'), findsOneWidget);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<AccountPeriod>),
        'Mes anterior',
      );
      expect(find.byKey(const ValueKey('movement-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('movement-2')), findsNothing);
      expect(find.text('GTQ 108.75'), findsOneWidget);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<AccountPeriod>),
        'Histórico',
      );
      await choose(
        tester,
        find.byKey(const ValueKey('history-month-2026-11')),
        'Septiembre',
      );
      expect(find.text('No hay movimientos en este período.'), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(
        find.byType(DropdownButtonFormField<AccountPeriod>),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<MovementType>), findsNothing);
      expect(find.byType(DropdownButtonFormField<Currency>), findsNothing);
    },
  );
  testWidgets(
    'Editar crédito configura fechas completas independientes y conserva período',
    (tester) async {
      await boot(tester);
      await openAccountDetails(tester, 2);
      expect(find.text('Sin configurar'), findsNWidgets(2));
      expect(find.text('Q 90.00'), findsOneWidget);
      expect(find.text(r'US$ 90.00'), findsNothing);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<AccountPeriod>),
        'Mes anterior',
      );
      await press(tester, find.byTooltip('Editar Crédito elegido'));
      Future<void> selectDate(int day) async {
        final button = find
            .widgetWithText(OutlinedButton, 'Sin configurar')
            .first;
        await press(tester, button);
        final dialog = find.byType(DatePickerDialog);
        final ok = MaterialLocalizations.of(tester.element(dialog))
            .okButtonLabel;
        await tester.tap(
          find.descendant(of: dialog, matching: find.text('$day')).last,
        );
        await tester.tap(find.text(ok).last);
        await tester.pumpAndSettle();
      }

      await selectDate(20);
      await selectDate(5);
      await tester.enterText(field('Alias'), 'Crédito actualizado');
      await press(tester, find.text('Guardar cuenta'));
      final model = accounts.stored[1].details;
      expect(model.nextClosingDate, DateTime(2026, 11, 20));
      expect(model.nextPaymentDueDate, DateTime(2026, 11, 5));
      expect(find.text('20/11'), findsOneWidget);
      expect(find.text('05/11'), findsOneWidget);
      expect(find.text('No hay movimientos en este período.'), findsOneWidget);
      expect(find.text('Q 10.00'), findsOneWidget);
      await closeAccountDetails(tester);
      expect(find.text('Crédito actualizado'), findsOneWidget);
      expect(find.text('GTQ 10.00'), findsOneWidget);
    },
  );
  testWidgets(
    'Débito sin identificación aclara alcance bancario y comparte saldo',
    (tester) async {
      await boot(tester);
      await openAccountDetails(tester, 1, debit: true);
      expect(
        find.text('Cuenta bancaria vinculada: Banco elegido · •••• 0042'),
        findsOneWidget,
      );
      expect(
        find.textContaining('aún no hay operaciones identificadas por tarjeta'),
        findsOneWidget,
      );
      expect(find.text('GTQ 108.75'), findsOneWidget);
      expect(find.byKey(const ValueKey('movement-2')), findsOneWidget);
      expect(movements.snapshot.accounts, hasLength(3));
    },
  );
  testWidgets(
    'Débito identificado incluye devolución y excluye banco sin etiqueta y otra tarjeta',
    (tester) async {
      await movements.createMovement(
        MovementDetails(
          type: MovementType.expense,
          accountId: 1,
          debitCardId: 1,
          amount: Money(200, Currency.gtq),
          date: DateTime(2026, 11, 1),
          description: 'Compra con débito',
        ),
      );
      await movements.createMovement(
        MovementDetails(
          type: MovementType.refund,
          accountId: 1,
          originalMovementId: 5,
          amount: Money(50, Currency.gtq),
          date: DateTime(2026, 11, 2),
          description: 'Devolución débito',
        ),
      );
      await accounts.createDebitCard(
        DebitCardDetails(name: 'Otra tarjeta', accountId: 1),
      );
      await movements.createMovement(
        MovementDetails(
          type: MovementType.expense,
          accountId: 1,
          debitCardId: 2,
          amount: Money(100, Currency.gtq),
          date: DateTime(2026, 11, 2),
          description: 'Compra otra tarjeta',
        ),
      );
      await boot(tester);
      await openAccountDetails(tester, 1, debit: true);
      expect(find.byKey(const ValueKey('movement-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('movement-6')), findsOneWidget);
      expect(find.byKey(const ValueKey('movement-2')), findsNothing);
      expect(find.byKey(const ValueKey('movement-7')), findsNothing);
      expect(
        find.textContaining('Solo movimientos identificados'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Detalle de movimiento abre desde cuenta y categorizar actualiza sin cambiar de sección',
    (tester) async {
      await boot(tester);
      await openAccountDetails(tester, 2);
      await openMovementDetails(tester, 3);
      await press(tester, find.text('Categorizar'));
      await press(tester, find.text('Guardar categoría'));
      expect(find.text('Detalle del movimiento'), findsOneWidget);
      await closeMovementDetails(tester);
      expect(find.text('Crédito elegido'), findsOneWidget);
      expect(find.text('Movimientos del período'), findsOneWidget);
      await closeAccountDetails(tester);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    },
  );
  testWidgets(
    'Carga fallida del detalle puede reintentarse y conserva la cuenta elegida',
    (tester) async {
      await boot(tester);
      movements.failLoad = true;
      await openAccountDetails(tester, 1);
      expect(
        find.textContaining('No se pudo cargar la cuenta ni sus movimientos'),
        findsOneWidget,
      );
      movements.failLoad = false;
      await press(tester, find.text('Reintentar'));
      expect(find.text('Banco elegido'), findsOneWidget);
      expect(find.byKey(const ValueKey('movement-2')), findsOneWidget);
    },
  );
  testWidgets(
    'Lista y detalle caben a 320 px con texto ampliado y montos largos',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await accounts.updateAccount(
        2,
        AccountDetails(
          name: 'Crédito con alias sintético suficientemente largo',
          type: AccountType.creditCard,
          openingBalance: Money(9007199254740000, Currency.gtq),
          secondaryOpeningBalance: Money(123456789012, Currency.usd),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
      await boot(tester);
      expect(tester.takeException(), isNull);
      await openAccountDetails(tester, 2);
      await tester.ensureVisible(find.text('Movimientos del período'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<AccountPeriod>),
        'Histórico',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
