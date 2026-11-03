import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/installment_plan.dart';
import 'package:mi_quetzal/domain/models/money.dart';

InstallmentDraft calendar({
  required DateTime first,
  int day = 31,
  int count = 4,
  int previous = 0,
  DateTime? reference,
}) => InstallmentDraft(
  description: 'Calendario sintético',
  accountId: 1,
  originalAmount: Money(10000, Currency.gtq),
  count: count,
  monthlyAmount: Money(2500, Currency.gtq),
  firstDate: first,
  chargeDay: day,
  previousCount: previous,
  referenceDate: reference ?? first,
  costMode: InstallmentCostMode.noInterest,
  limitMode: InstallmentLimitMode.ordinary,
);
void main() {
  for (final year in [2027, 2028]) {
    for (final day in [29, 30, 31]) {
      test('Día $day en febrero de $year vuelve al día original en marzo', () {
        final schedule = calendar(
          first: DateTime(year, 1, day),
          day: day,
        ).buildSchedule();
        expect(schedule.map((r) => r.date).toList(), [
          DateTime(year, 1, day),
          DateTime(year, 2, year == 2028 ? 29 : 28),
          DateTime(year, 3, day),
          DateTime(year, 4, day == 31 ? 30 : day),
        ]);
      });
    }
  }
  test('Cambio de año utiliza meses calendario y conserva numeración', () {
    final rows = calendar(first: DateTime(2027, 12, 31)).buildSchedule();
    expect(rows.map((r) => r.date).toList(), [
      DateTime(2027, 12, 31),
      DateTime(2028, 1, 31),
      DateTime(2028, 2, 29),
      DateTime(2028, 3, 31),
    ]);
    expect(rows.map((r) => r.number).toList(), [1, 2, 3, 4]);
  });
  test('Referencia impide volver a generar cuotas previamente cargadas', () {
    final rows = calendar(
      first: DateTime(2026, 1, 31),
      previous: 2,
      reference: DateTime(2026, 3, 1),
    ).buildSchedule();
    expect(rows.map((r) => r.previouslyLoaded), [true, true, false, false]);
    expect(
      () => calendar(
        first: DateTime(2026, 1, 31),
        previous: 2,
        reference: DateTime(2026, 3, 31),
      ),
      throwsA(isA<InstallmentValidationException>()),
    );
    expect(
      () => calendar(
        first: DateTime(2026, 1, 31),
        previous: 2,
        reference: DateTime(2026, 2, 1),
      ),
      throwsA(isA<InstallmentValidationException>()),
    );
  });
  test(
    'Moneda compacta mantiene símbolo e importe unidos con dos decimales',
    () {
      expect(Money(123456, Currency.gtq).compact, 'Q\u00a01,234.56');
      expect(Money(123456, Currency.usd).compact, 'US\$\u00a01,234.56');
    },
  );
}
