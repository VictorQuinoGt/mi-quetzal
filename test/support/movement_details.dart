import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openMovementDetails(WidgetTester tester, int id) async {
  if (find.text('Detalle del movimiento').evaluate().isNotEmpty) return;
  final button = find.byKey(ValueKey('movement-detail-$id'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> closeMovementDetails(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}
