import 'package:flutter/material.dart';

import '../../support/navigation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/ui/core/date_input.dart';
import 'package:mi_quetzal/ui/movements/movements_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';
import '../../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  late FakeAccountRepository accounts;
  late FakeMovementRepository repository;
  late MovementsViewModel vm;
  setUp(() async {
    accounts = FakeAccountRepository();
    await accounts.createAccount(
      AccountDetails(
        name: 'Banco de prueba',
        type: AccountType.bank,
        openingBalance: Money(10000, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    repository = FakeMovementRepository(accounts);
    vm = MovementsViewModel(repository, now: () => DateTime(2026, 11, 15));
    await vm.load();
  });
  tearDown(() => vm.dispose());

  Future<bool> save(String text) => vm.createMovement(
    type: MovementType.expense,
    accountId: 1,
    amount: '1.25',
    description: 'Movimiento de prueba',
    dateInput: text,
  );

  test('El formato numérico conserva día, mes y año', () {
    expect(DateInput.format(DateTime(2026, 1, 5)), '05/01/2026');
    expect(DateInput.tryParse('05/01/2026'), DateTime(2026, 1, 5));
    expect(DateInput.tryParse('29/02/2024'), DateTime(2024, 2, 29));
    expect(DateInput.tryParse('29/02/2000'), DateTime(2000, 2, 29));
  });

  test('No normaliza fechas inexistentes ni interpreta otro formato', () {
    for (final text in [
      '',
      '5/1/2026',
      '2026-01-05',
      '31/02/2026',
      '31/04/2026',
      '29/02/2025',
      '29/02/1900',
      '29/02/2100',
      '00/11/2026',
      '15/00/2026',
      '15/13/2026',
      '15/11/0000',
      '15/11/1899',
    ]) {
      expect(DateInput.tryParse(text), isNull, reason: text);
    }
  });

  test('Guarda la fecha escrita sin sustituirla por la fecha actual', () async {
    expect(await save('10/11/2026'), isTrue);
    expect(repository.stored.single.details.date, DateTime(2026, 11, 10));
  });

  test('Fechas inválidas o futuras no escriben', () async {
    for (final text in ['31/02/2026', '', '16/11/2026']) {
      expect(await save(text), isFalse, reason: text);
      expect(vm.fieldErrors, contains('date'));
    }
    expect(repository.createCalls, 0);
  });

  test(
    'Permite fecha manual anterior al alta sin alterar el saldo inicial',
    () async {
      expect(await save('30/09/2026'), isTrue);
      expect(repository.stored.single.details.date, DateTime(2026, 9, 30));
      final account = repository.snapshot.accounts.single;
      expect(account.details.openingDate, DateTime(2026, 10, 1));
      expect(account.details.openingBalance.minorUnits, 10000);
      expect(account.currentBalance.minorUnits, 9875);
    },
  );

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(repository: accounts, movements: repository),
    );
    await tester.pumpAndSettle();
    await openAccountMovement(tester, 1);
    await tester.ensureVisible(field('Descripción'));
    await tester.enterText(field('Descripción'), 'Fecha escrita de prueba');
    await tester.ensureVisible(field('Importe'));
    await tester.enterText(field('Importe'), '1.25');
  }

  Future<void> submit(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'La fecha se puede escribir y corregir sin perder el formulario',
    (tester) async {
      await openForm(tester);
      await tester.ensureVisible(field('Fecha del movimiento'));
      await tester.enterText(field('Fecha del movimiento'), '31/02/2026');
      await submit(tester);
      expect(repository.stored, isEmpty);
      expect(
        find.text('Escribe una fecha válida con formato dd/mm/yyyy.'),
        findsOneWidget,
      );
      expect(find.text('Fecha escrita de prueba'), findsOneWidget);
      await tester.ensureVisible(field('Fecha del movimiento'));
      await tester.enterText(field('Fecha del movimiento'), '10/11/2026');
      await submit(tester);
      expect(repository.stored.single.details.date, DateTime(2026, 11, 10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'El calendario abre en la fecha escrita y actualiza el mismo campo',
    (tester) async {
      await openForm(tester);
      await tester.ensureVisible(field('Fecha del movimiento'));
      await tester.enterText(field('Fecha del movimiento'), '10/11/2026');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Elegir fecha en el calendario'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .initialDate,
        DateTime(2026, 11, 10),
      );
      await tester.tap(find.text('9').last);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field('Fecha del movimiento'))
            .controller!
            .text,
        '09/11/2026',
      );
      await submit(tester);
      expect(repository.stored.single.details.date, DateTime(2026, 11, 9));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Abrir el calendario con texto inválido o futuro no falla', (
    tester,
  ) async {
    await openForm(tester);
    for (final text in ['31/02/2026', '31/12/9999']) {
      await tester.ensureVisible(field('Fecha del movimiento'));
      await tester.enterText(field('Fecha del movimiento'), text);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Elegir fecha en el calendario'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final cancel = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).cancelButtonLabel;
      await tester.tap(find.text(cancel));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field('Fecha del movimiento'))
            .controller!
            .text,
        text,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
