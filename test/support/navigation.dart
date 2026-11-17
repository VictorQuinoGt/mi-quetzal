import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> selectAppSection(WidgetTester tester, String label) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  while (navigator.canPop()) {
    navigator.pop();
    await tester.pumpAndSettle();
  }
  final target = find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is NavigationBar || w is NavigationRail,
    ),
    matching: find.text(label),
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openHistory(WidgetTester tester, {bool filters = true}) async {
  await selectAppSection(tester, 'Inicio');
  final button = find.text('Ver historial general');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  if (filters && find.byType(ExpansionTile).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.byType(ExpansionTile));
    if (find.byType(TextField).evaluate().isEmpty) {
      await tester.tap(find.textContaining('Filtros').first);
      await tester.pumpAndSettle();
    }
  }
}

Future<void> openCategoryCatalog(WidgetTester tester) async {
  await selectAppSection(tester, 'Ajustes');
  await tester.tap(find.text('Categorías'));
  await tester.pumpAndSettle();
}

Future<void> openAccountMovement(
  WidgetTester tester,
  int id, {
  String operation = 'Gasto',
  bool debit = false,
}) async {
  await selectAppSection(tester, 'Cuentas');
  final account = find.byKey(ValueKey('${debit ? 'debit' : 'account'}-$id'));
  await tester.ensureVisible(account);
  await tester.tap(account);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(operation));
  await tester.pumpAndSettle();
}
