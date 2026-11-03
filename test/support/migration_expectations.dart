import 'package:flutter_test/flutter_test.dart';

void expectPreservedRows(
  List<Map<String, Object?>> actual,
  List<Map<String, Object?>> original,
) {
  expect(actual, hasLength(original.length));
  for (final row in original) {
    final preserved = actual.singleWhere(
      (candidate) => candidate['id'] == row['id'],
    );
    for (final field in row.keys) {
      expect(
        preserved[field],
        row[field],
        reason: 'Registro ${row['id']} / $field',
      );
    }
  }
}
