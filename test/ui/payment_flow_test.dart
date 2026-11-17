import 'package:flutter/material.dart';

import '../support/navigation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/movements/movement_row.dart';

import '../support/account_details.dart';
import '../support/fake_account_repository.dart';
import '../support/fake_movement_repository.dart';
import '../support/movement_details.dart';
import '../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Finder dropdown(String label) => find.byWidgetPredicate(
  (w) => w is DropdownButtonFormField<int> && w.decoration.labelText == label,
);
Future<void> press(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
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

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository movements;
  setUp(() async {
    accounts = FakeAccountRepository();
    await accounts.createAccount(
      AccountDetails(
        name: 'Crédito sintético',
        type: AccountType.creditCard,
        openingBalance: Money(10000, Currency.gtq),
        secondaryOpeningBalance: Money(3000, Currency.usd),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    movements = FakeMovementRepository(accounts);
  });
  Future<void> openPayment(WidgetTester tester) async {
    await press(tester, find.text('Cuentas').last);
    await openAccountDetails(tester, 1);
    await press(tester, find.byType(FloatingActionButton));
    await press(tester, find.text('Pago'));
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(field('Descripción'));
    await tester.enterText(field('Descripción'), 'Pago sintético');
    await tester.ensureVisible(field('Importe'));
    await tester.enterText(field('Importe'), '12.50');
    await press(tester, find.text('Guardar movimiento'));
  }

  testWidgets(
    'Crea categoría Pago y paga USD en agencia sin registrar banco ni efectivo',
    (tester) async {
      await tester.pumpWidget(
        testApp(repository: accounts, movements: movements),
      );
      await tester.pumpAndSettle();
      await openCategoryCatalog(tester);
      await press(tester, find.text('Agregar categoría'));
      await tester.enterText(field('Nombre de categoría'), 'Abono sintético');
      await choose(
        tester,
        find.byType(DropdownButtonFormField<CategoryKind>),
        'Pago',
      );
      await press(tester, find.text('Agregar'));
      expect(movements.categories.single.details.kind, CategoryKind.payment);
      await press(tester, find.byType(BackButton));
      await openPayment(tester);
      expect(dropdown('Cuenta de origen'), findsNothing);
      expect(find.text('Efectivo en agencia'), findsOneWidget);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<Currency>),
        'USD',
      );
      await choose(tester, dropdown('Categoría (opcional)'), 'Abono sintético');
      await save(tester);
      final payment = movements.stored.single;
      expect(payment.details.paymentFunding, PaymentFunding.externalCash);
      expect(payment.details.categoryId, movements.categories.single.id);
      expect(movements.snapshot.accounts, hasLength(1));
      expect(
        movements.snapshot.accounts.single.balanceFor(Currency.usd)!.minorUnits,
        1750,
      );
      expect(
        movements.snapshot.accounts.single.balanceFor(Currency.gtq)!.minorUnits,
        10000,
      );
      expect(find.text('P'), findsOneWidget);
      expect(find.text('Pago de tarjeta'), findsNothing);
      await openMovementDetails(tester, payment.id);
      expect(find.text('Origen: Efectivo en agencia'), findsOneWidget);
      expect(find.text('Categoría: Abono sintético'), findsOneWidget);
      await press(tester, find.text('Categorizar'));
      await choose(
        tester,
        find.byType(DropdownButtonFormField<int>),
        'Sin categoría',
      );
      await press(tester, find.text('Guardar categoría'));
      expect(movements.stored.single.details.categoryId, isNull);
      expect(
        movements.stored.single.details.paymentFunding,
        PaymentFunding.externalCash,
      );
      expect(
        movements.snapshot.accounts.single.balanceFor(Currency.usd)!.minorUnits,
        1750,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Permite elegir agencia o efectivo registrado y conserva la categoría al cambiar forma',
    (tester) async {
      await accounts.createAccount(
        AccountDetails(
          name: 'Efectivo sintético',
          type: AccountType.cash,
          openingBalance: Money(5000, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
        ),
      );
      await movements.createCategory(
        CategoryDetails(name: 'Abono sintético', kind: CategoryKind.payment),
      );
      await movements.createCategory(
        CategoryDetails(name: 'Gasto sintético', kind: CategoryKind.expense),
      );
      await tester.pumpWidget(
        testApp(repository: accounts, movements: movements),
      );
      await tester.pumpAndSettle();
      await openPayment(tester);
      await choose(tester, dropdown('Categoría (opcional)'), 'Abono sintético');
      await choose(
        tester,
        find.byType(DropdownButtonFormField<PaymentFunding>),
        'Efectivo en agencia',
      );
      expect(dropdown('Cuenta de origen'), findsNothing);
      await choose(
        tester,
        find.byType(DropdownButtonFormField<PaymentFunding>),
        'Desde una cuenta',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<int>>(
              dropdown('Categoría (opcional)'),
            )
            .initialValue,
        1,
      );
      await press(tester, dropdown('Categoría (opcional)'));
      expect(find.text('Gasto sintético'), findsNothing);
      await tester.tap(find.text('Abono sintético').last);
      await tester.pumpAndSettle();
      await choose(
        tester,
        dropdown('Cuenta de origen'),
        'Efectivo sintético · GTQ',
      );
      await save(tester);
      expect(
        movements.stored.single.details.paymentFunding,
        PaymentFunding.account,
      );
      expect(
        movements.snapshot.accounts.map((a) => a.currentBalance.minorUnits),
        [8750, 3750],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Filas compactas G/P conservan accesibilidad y admiten texto ampliado sin desbordar',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var opened = 0;
      for (final entry in [(390.0, 1.0), (320.0, 2.0)]) {
        tester.view.physicalSize = Size(entry.$1, 900);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(entry.$2)),
              child: Scaffold(
                body: Column(
                  children: [
                    for (final type in [
                      MovementType.expense,
                      MovementType.creditPayment,
                    ])
                      MovementRow(
                        movement: Movement(
                          id: type.index,
                          details: MovementDetails(
                            type: type,
                            accountId: 1,
                            paymentFunding: type == MovementType.creditPayment
                                ? PaymentFunding.externalCash
                                : PaymentFunding.account,
                            amount: Money(
                              entry.$2 == 1 ? 1250 : 9007199254740991,
                              Currency.gtq,
                            ),
                            date: DateTime(2026, 11, 1),
                            description: entry.$2 == 1
                                ? 'Movimiento sintético'
                                : 'Descripción sintética extensa para texto ampliado',
                          ),
                        ),
                        category: 'Categoría sintética',
                        onDetails: () => opened++,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('G'), findsOneWidget);
        expect(find.text('P'), findsOneWidget);
        expect(find.text('Compra o gasto'), findsNothing);
        expect(find.text('Pago de tarjeta'), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('Pago de tarjeta.*Abrir movimiento')),
          findsWidgets,
        );
        if (entry.$2 == 1) {
          expect(
            tester.getSize(find.byKey(const ValueKey('movement-0'))).height,
            lessThan(100),
          );
        }
        await tester.tap(find.text('P'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(opened, 2);
      semantics.dispose();
    },
  );
}
