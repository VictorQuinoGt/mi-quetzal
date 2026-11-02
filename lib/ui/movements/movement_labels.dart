import '../../domain/models/movement.dart';

extension MovementTypeLabel on MovementType {
  String get label => switch (this) {
    MovementType.expense => 'Compra o gasto',
    MovementType.income => 'Ingreso',
    MovementType.transfer => 'Transferencia',
    MovementType.creditPayment => 'Pago de tarjeta',
    MovementType.refund => 'Devolución',
  };
  String get explanation => switch (this) {
    MovementType.expense => 'Con efectivo o banco reduce fondos. Con crédito aumenta la deuda. Se cuenta una sola vez como gasto.',
    MovementType.income =>
      'Aumenta el saldo de efectivo o de una cuenta bancaria.',
    MovementType.transfer => 'Mueve fondos entre efectivo y cuentas bancarias de la misma moneda. No es ingreso ni gasto.',
    MovementType.creditPayment => 'Reduce fondos de origen y deuda de la tarjeta. No es un segundo gasto. Un pago mayor a la deuda deja saldo a favor.',
    MovementType.refund => 'Revierte un gasto en la misma cuenta y moneda de la compra. Reduce gastos del mes de la devolución; no es un ingreso.',
  };
}
