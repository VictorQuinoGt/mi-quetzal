import '../models/account.dart';
import '../models/debit_card.dart';
import '../models/movement.dart';

abstract final class AccountRules {
  static void validateUpdate(
    Account original,
    AccountDetails updated, {
    List<Movement> movements = const [],
  }) {
    if (original.details.type != updated.type) {
      throw ArgumentError(
        'El tipo de una cuenta existente se conserva para mantener su historial.',
        'type',
      );
    }
    if (original.details.openingBalance.currency !=
        updated.openingBalance.currency) {
      throw ArgumentError(
        'La moneda de la cuenta existente se conserva. En crédito puedes añadir la otra moneda.',
        'currency',
      );
    }
    if (movements.any(
      (m) =>
          (m.details.accountId == original.id ||
              m.details.counterpartyAccountId == original.id) &&
          updated.openingBalanceFor(m.details.amount.currency) == null,
    )) {
      throw ArgumentError(
        'Esta moneda ya tiene movimientos. Conserva su saldo inicial para mantener el historial.',
        'secondaryOpeningBalance',
      );
    }
  }

  static void validateDebitUpdate(
    int id,
    DebitCardDetails updated,
    List<Movement> movements,
  ) {
    if (movements.any(
      (m) =>
          m.details.debitCardId == id &&
          m.details.accountId != updated.accountId,
    )) {
      throw const DebitCardValidationException(
        'account',
        'Esta tarjeta ya tiene compras. Conserva su cuenta bancaria vinculada.',
      );
    }
  }
}
