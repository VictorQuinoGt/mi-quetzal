import '../models/account.dart';
import '../models/category.dart';
import '../models/debit_card.dart';
import '../models/money.dart';
import '../models/movement.dart';

abstract final class MovementRules {
  static bool canBeOrigin(Account account, MovementType type) =>
      type == MovementType.expense ||
      type == MovementType.refund ||
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
    List<Category> categories = const [],
    List<Movement> movements = const [],
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
      if (account.details.openingBalanceFor(movement.amount.currency) == null) {
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
    if (movement.categoryId != null &&
        !categories.any(
          (category) =>
              category.id == movement.categoryId &&
              category.details.supports(movement.type),
        )) {
      throw const MovementValidationException(
        'category',
        'Selecciona una categoría compatible con esta operación.',
      );
    }
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
      case MovementType.refund:
        validateRefund(movement, movements);
        return {
          origin.id: origin.details.type == AccountType.creditCard
              ? amount.negated
              : amount,
        };
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
    List<Category> categories = const [],
    List<Movement> movements = const [],
  }) {
    final today = DateTime(now.year, now.month, now.day);
    if (movement.date.isAfter(today)) {
      throw const MovementValidationException(
        'date',
        'No puedes registrar un movimiento con fecha futura.',
      );
    }
    effects(
      movement,
      accounts,
      debitCards: debitCards,
      categories: categories,
      movements: movements,
    );
  }

  static Money remainingRefund(Movement original, List<Movement> movements) {
    final total = movements
        .where(
          (m) =>
              m.details.isRefund && m.details.originalMovementId == original.id,
        )
        .fold(
          BigInt.zero,
          (sum, m) => sum + BigInt.from(m.details.amount.minorUnits),
        );
    return Money.fromBigInt(
      BigInt.from(original.details.amount.minorUnits) - total,
      original.details.amount.currency,
    );
  }

  static void validateRefund(MovementDetails refund, List<Movement> movements) {
    final matches = movements.where((m) => m.id == refund.originalMovementId);
    if (matches.length != 1 || !matches.single.details.isExpense) {
      throw const MovementValidationException(
        'originalMovement',
        'Selecciona una compra o gasto existente para devolver.',
      );
    }
    final original = matches.single;
    if (original.details.accountId != refund.accountId ||
        original.details.amount.currency != refund.amount.currency) {
      throw const MovementValidationException(
        'originalMovement',
        'La devolución debe usar la misma cuenta y moneda de la compra.',
      );
    }
    if (refund.date.isBefore(original.details.date)) {
      throw const MovementValidationException(
        'date',
        'La devolución no puede ser anterior a la compra.',
      );
    }
    if (BigInt.from(refund.amount.minorUnits) >
        BigInt.from(remainingRefund(original, movements).minorUnits)) {
      throw const MovementValidationException(
        'amount',
        'El importe supera el pendiente de devolver de esta compra.',
      );
    }
  }
}
