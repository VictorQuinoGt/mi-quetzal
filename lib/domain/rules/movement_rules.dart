import '../models/account.dart';
import '../models/debit_card.dart';
import '../models/money.dart';
import '../models/movement.dart';

abstract final class MovementRules {
  static bool canBeOrigin(Account account, MovementType type) =>
      type == MovementType.expense ||
      account.details.type != AccountType.creditCard;

  static bool canBeDestination(Account account, MovementType type) =>
      switch (type) {
        MovementType.transfer => account.details.type != AccountType.creditCard,
        MovementType.creditPayment =>
          account.details.type == AccountType.creditCard,
        _ => false,
      };

  static Map<int, Money> effects(
    MovementDetails movement,
    List<Account> accounts, {
    List<DebitCard> debitCards = const [],
  }) {
    final byId = {for (final account in accounts) account.id: account};
    final origin = byId[movement.accountId];
    if (origin == null || !canBeOrigin(origin, movement.type)) {
      throw const MovementValidationException(
        'account',
        'Selecciona una cuenta válida para esta operación.',
      );
    }
    void validateAccount(Account account) {
      if (account.details.openingBalance.currency != movement.amount.currency) {
        throw const MovementValidationException(
          'counterparty',
          'Las cuentas deben usar la misma moneda. Las conversiones aún no están disponibles.',
        );
      }
      if (movement.date.isBefore(account.details.openingDate)) {
        throw const MovementValidationException(
          'date',
          'La fecha no puede ser anterior al saldo inicial de las cuentas involucradas.',
        );
      }
    }

    validateAccount(origin);
    if (movement.debitCardId != null &&
        !debitCards.any(
          (card) =>
              card.id == movement.debitCardId &&
              card.details.accountId == origin.id &&
              origin.details.type == AccountType.bank,
        )) {
      throw const MovementValidationException(
        'debitCard',
        'Selecciona una tarjeta de débito vinculada a la cuenta de origen.',
      );
    }
    final amount = movement.amount;
    switch (movement.type) {
      case MovementType.expense:
        return {
          origin.id: origin.details.type == AccountType.creditCard
              ? amount
              : amount.negated,
        };
      case MovementType.income:
        return {origin.id: amount};
      case MovementType.transfer:
      case MovementType.creditPayment:
        final other = byId[movement.counterpartyAccountId];
        if (other == null || !canBeDestination(other, movement.type)) {
          throw const MovementValidationException(
            'counterparty',
            'Selecciona un destino válido para esta operación.',
          );
        }
        validateAccount(other);
        return {
          origin.id: amount.negated,
          other.id: movement.type == MovementType.creditPayment
              ? amount.negated
              : amount,
        };
    }
  }

  static void validateRegistration(
    MovementDetails movement,
    List<Account> accounts,
    DateTime now, {
    List<DebitCard> debitCards = const [],
  }) {
    final today = DateTime(now.year, now.month, now.day);
    if (movement.date.isAfter(today)) {
      throw const MovementValidationException(
        'date',
        'No puedes registrar un movimiento con fecha futura.',
      );
    }
    effects(movement, accounts, debitCards: debitCards);
  }
}
