import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'navigation.dart';

Future<void> openAccountDetails(
  WidgetTester tester,
  int id, {
  bool debit = false,
}) async {
  final card = find.byKey(ValueKey('${debit ? 'debit' : 'account'}-$id'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> closeAccountDetails(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

Future<void> openFinancialAdministration(WidgetTester tester) async {
  await selectAppSection(tester, 'Ajustes');
  await tester.tap(find.text('Entidades financieras'));
  await tester.pumpAndSettle();
}
