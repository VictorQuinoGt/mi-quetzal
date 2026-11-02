import '../rules/movement_rules.dart';
import 'account.dart';
import 'movement.dart';

final class LedgerSnapshot {
  LedgerSnapshot.calculate(List<Account> accounts, List<Movement> movements) {
    final balances = {
      for (final account in accounts)
        account.id: account.details.openingBalance,
    };
    final chronological = [...movements]
      ..sort((a, b) {
        final dateOrder = a.details.date.compareTo(b.details.date);
        return dateOrder == 0 ? a.id.compareTo(b.id) : dateOrder;
      });
    for (final movement in chronological) {
      final effects = MovementRules.effects(movement.details, accounts);
      for (final entry in effects.entries) {
        try {
          final balance = balances[entry.key]!.add(entry.value);
          final account = accounts.firstWhere((a) => a.id == entry.key);
          if (account.details.type == AccountType.cash &&
              balance.minorUnits < 0) {
            throw const MovementValidationException(
              'amount',
              'El efectivo no puede quedar negativo. Revisa el importe y las fechas de tus operaciones.',
            );
          }
          balances[entry.key] = balance;
        } on ArgumentError {
          throw const MovementValidationException(
            'amount',
            'La operación excede el rango de saldos admitido.',
          );
        }
      }
    }
    this.accounts = List.unmodifiable([
      for (final account in accounts)
        Account(
          id: account.id,
          details: account.details,
          currentBalance: balances[account.id],
        ),
    ]);
    this.movements = List.unmodifiable(chronological.reversed);
  }

  late final List<Account> accounts;
  late final List<Movement> movements;
}
