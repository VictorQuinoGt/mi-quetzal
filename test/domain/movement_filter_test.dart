import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/models/movement_filter.dart';

void main() {
  Movement item(
    int id,
    MovementType type,
    int source, {
    int? other,
    String text = 'Compra sintética',
    Currency currency = Currency.gtq,
  }) => Movement(
    id: id,
    details: MovementDetails(
      type: type,
      accountId: source,
      counterpartyAccountId: other,
      amount: Money(100, currency),
      date: DateTime(2026, 10, id),
      description: text,
    ),
  );
  final movements = [
    item(
      4,
      MovementType.expense,
      2,
      currency: Currency.usd,
      text: 'Farmacia sintética',
    ),
    item(3, MovementType.creditPayment, 1, other: 3, text: 'Pago sintético'),
    item(2, MovementType.transfer, 1, other: 2, text: 'Retiro sintético'),
    item(1, MovementType.expense, 1, text: 'Farmacia 100% sintética'),
  ];

  test('Filtro vacío conserva identidad, orden y todas las operaciones', () {
    final filter = MovementFilter(query: '  ');
    expect(filter.isActive, isFalse);
    expect(filter.apply(movements), movements);
    expect(() => filter.apply(movements).clear(), throwsUnsupportedError);
  });

  test(
    'Combina búsqueda literal, moneda y tipo sin modificar el historial',
    () {
      final filter = MovementFilter(
        query: '  FARMACIA ',
        currency: Currency.gtq,
        type: MovementType.expense,
      );
      expect(filter.apply(movements).map((m) => m.id), [1]);
      expect(MovementFilter(query: '100%').apply(movements).map((m) => m.id), [
        1,
      ]);
      expect(movements.map((m) => m.id), [4, 3, 2, 1]);
    },
  );

  test(
    'Cuenta incluye ambas caras de transferencias y pagos sin duplicar filas',
    () {
      expect(MovementFilter(accountId: 2).apply(movements).map((m) => m.id), [
        4,
        2,
      ]);
      final payment = MovementFilter(accountId: 3).apply(movements).single;
      expect(payment.id, 3);
      expect(payment.details.isExpense, isFalse);
    },
  );

  test('Rango de fechas incluye ambos límites y normaliza horas', () {
    final filter = MovementFilter(
      from: DateTime(2026, 10, 2, 22),
      to: DateTime(2026, 10, 3, 1),
    );
    expect(filter.apply(movements).map((m) => m.id), [3, 2]);
    expect(
      MovementFilter(from: DateTime(2026, 10, 4)).apply(movements).single.id,
      4,
    );
    expect(
      MovementFilter(to: DateTime(2026, 10, 1)).apply(movements).single.id,
      1,
    );
    expect(
      () => MovementFilter(
        from: DateTime(2026, 10, 3),
        to: DateTime(2026, 10, 2),
      ),
      throwsArgumentError,
    );
  });

  test('Una combinación sin coincidencias devuelve vacío', () {
    expect(
      MovementFilter(currency: Currency.usd, accountId: 3).apply(movements),
      isEmpty,
    );
    expect(
      MovementFilter(query: 'Sin coincidencias').apply(movements),
      isEmpty,
    );
  });
}
