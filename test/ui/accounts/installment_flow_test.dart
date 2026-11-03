import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/app/mi_quetzal_app.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/data/repositories/sqlite_installment_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/installment_plan.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> press(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await settle(tester);
}

void main() {
  setUpAll(sqfliteFfiInit);
  testWidgets(
    'Crea con calendario, actualiza detalle/lista y cancela sin borrar la cuota',
    (tester) async {
      final now = DateTime.now();
      final database = LocalDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final accounts = SqliteAccountRepository(database);
      final movements = SqliteMovementRepository(database);
      final plans = SqliteInstallmentRepository(database);
      addTearDown(database.close);
      await tester.runAsync(
        () => accounts.createAccount(
          AccountDetails(
            name: 'Tarjeta sintética',
            type: AccountType.creditCard,
            openingBalance: Money(0, Currency.gtq),
            creditLimit: Money(100000, Currency.gtq),
            openingDate: DateTime(now.year, now.month, 1),
          ),
        ),
      );
      await tester.pumpWidget(
        MiQuetzalApp(
          accountRepository: accounts,
          movementRepository: movements,
          installmentRepository: plans,
        ),
      );
      await settle(tester);
      await press(tester, find.text('Cuentas').last);
      await press(tester, find.byKey(const ValueKey('account-1')));
      await press(tester, find.text('Cuotas'));
      await press(tester, find.text('Agregar compra en cuotas'));
      for (final value in {
        'Descripción o comercio': 'Compra de prueba',
        'Monto original': '100.00',
        'Número total de cuotas': '3',
        'Importe mensual real': '33.33',
      }.entries) {
        await tester.ensureVisible(field(value.key));
        await tester.enterText(field(value.key), value.value);
      }
      await press(tester, find.text('Ver calendario antes de guardar'));
      expect(find.text('Calendario propuesto'), findsOneWidget);
      expect(find.textContaining('Q\u00a033.34'), findsOneWidget);
      await press(tester, find.text('Guardar plan y calendario'));
      expect(find.text('Compra en cuotas'), findsNothing);
      expect(find.text('Compra de prueba'), findsOneWidget);
      expect(find.textContaining('1 de 3 cuotas cargadas'), findsOneWidget);
      final first = await tester.runAsync(plans.generateDue);
      expect(first!.accounts.single.currentBalance.minorUnits, 3333);
      expect(first.installmentPlans.single.pendingAmount.minorUnits, 6667);
      await press(tester, find.text('Compra de prueba'));
      await press(tester, find.text('Cancelar cargos futuros'));
      await press(tester, find.text('Cancelar plan'));
      expect(find.textContaining('Cancelado'), findsWidgets);
      await press(tester, find.byType(BackButton));
      await press(tester, find.byType(BackButton));
      expect(find.text('GTQ 33.33'), findsOneWidget);
      final result = await tester.runAsync(plans.generateDue);
      expect(result!.movements, hasLength(1));
      expect(
        result.installmentPlans.single.state,
        InstallmentPlanState.cancelled,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
    },
  );

  testWidgets(
    'Reanudar carga vencidas y refresca tanto el detalle abierto como Cuentas',
    (tester) async {
      final current = DateTime.now();
      var now = DateTime(current.year, current.month, 1);
      final database = LocalDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final accounts = SqliteAccountRepository(database, now: () => now);
      final movements = SqliteMovementRepository(database, now: () => now);
      final plans = SqliteInstallmentRepository(database, now: () => now);
      addTearDown(database.close);
      await tester.runAsync(() async {
        await accounts.createAccount(
          AccountDetails(
            name: 'Tarjeta reanudada',
            type: AccountType.creditCard,
            openingBalance: Money(0, Currency.gtq),
            creditLimit: Money(100000, Currency.gtq),
            openingDate: DateTime(current.year, 1, 1),
          ),
        );
        await plans.createPlan(
          InstallmentDraft(
            description: 'Plan al reanudar',
            accountId: 1,
            originalAmount: Money(3000, Currency.gtq),
            count: 3,
            monthlyAmount: Money(1000, Currency.gtq),
            firstDate: now,
            chargeDay: 1,
            previousCount: 0,
            referenceDate: now,
            costMode: InstallmentCostMode.noInterest,
            limitMode: InstallmentLimitMode.ordinary,
          ),
        );
      });
      await tester.pumpWidget(
        MiQuetzalApp(
          accountRepository: accounts,
          movementRepository: movements,
          installmentRepository: plans,
        ),
      );
      await settle(tester);
      await press(tester, find.text('Cuentas').last);
      await press(tester, find.byKey(const ValueKey('account-1')));
      expect(find.text('Q\u00a010.00'), findsOneWidget);
      now = DateTime(current.year, current.month + 2, 1);
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await settle(tester);
      expect(find.text('Q\u00a030.00'), findsOneWidget);
      await press(tester, find.byType(BackButton));
      expect(find.text('GTQ 30.00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
    },
  );
}
