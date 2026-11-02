import '../rules/movement_rules.dart';
import 'account.dart';
import 'category.dart';
import 'debit_card.dart';
import 'movement.dart';

final class LedgerSnapshot {
  LedgerSnapshot.calculate(
    List<Account> accounts,
    List<Movement> movements, {
    List<DebitCard> debitCards = const [],
    List<Category> categories = const [],
  }) {
    for (final card in debitCards) {
      card.details.validateAccount(accounts);
    }
    final balances = {
      for (final account in accounts)
        for (final balance in account.details.openingBalances)
          (account.id, balance.currency): balance,
    };
    final chronological = [...movements]
      ..sort((a, b) {
        final dateOrder = a.details.date.compareTo(b.details.date);
        return dateOrder == 0 ? a.id.compareTo(b.id) : dateOrder;
      });
    final processed = <Movement>[];
    for (final movement in chronological) {
      final effects = MovementRules.effects(
        movement.details,
        accounts,
        debitCards: debitCards,
        categories: categories,
        movements: processed,
      );
      for (final entry in effects.entries) {
        try {
          final key = (entry.key, entry.value.currency);
          final balance = balances[key]!.add(entry.value);
          final account = accounts.firstWhere((a) => a.id == entry.key);
          if (account.details.type == AccountType.cash &&
              balance.minorUnits < 0) {
            throw const MovementValidationException(
              'amount',
              'El efectivo no puede quedar negativo. Revisa el importe y las fechas de tus operaciones.',
            );
          }
          balances[key] = balance;
        } on ArgumentError {
          throw const MovementValidationException(
            'amount',
            'La operación excede el rango de saldos admitido.',
          );
        }
      }
      processed.add(movement);
    }
    this.accounts = List.unmodifiable([
      for (final account in accounts)
        Account(
          id: account.id,
          details: account.details,
          currentBalance:
              balances[(account.id, account.details.openingBalance.currency)],
          secondaryCurrentBalance:
              account.details.secondaryOpeningBalance == null
              ? null
              : balances[(
                  account.id,
                  account.details.secondaryOpeningBalance!.currency,
                )],
        ),
    ]);
    this.movements = List.unmodifiable(chronological.reversed);
    this.debitCards = List.unmodifiable(debitCards);
    this.categories = List.unmodifiable(categories);
  }

  late final List<Account> accounts;
  late final List<Movement> movements;
  late final List<DebitCard> debitCards;
  late final List<Category> categories;
}
