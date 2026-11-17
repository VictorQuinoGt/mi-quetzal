import 'account.dart';
import 'ledger_snapshot.dart';
import 'money.dart';

final class CurrencyDebt {
  const CurrencyDebt({
    required this.debt,
    required this.credit,
    required this.futureInstallments,
    required this.installmentCount,
  });
  final Money debt;
  final Money credit;
  final Money futureInstallments;
  final int installmentCount;
}

/// Deuda cargada y compromisos futuros separados, sin compensar entre tarjetas.
final class DebtOverview {
  DebtOverview.calculate(LedgerSnapshot snapshot, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    cards = List.unmodifiable(
      snapshot.accounts.where((a) => a.details.type == AccountType.creditCard),
    );
    cardsWithDebt = cards
        .where((a) => a.currentBalances.any((m) => m.minorUnits > 0))
        .length;
    currencies = List.unmodifiable([
      for (final currency in Currency.values) _total(snapshot, currency, today),
    ]);
    upcomingPayments = List.unmodifiable(
      (cards
            .where(
              (a) =>
                  a.details.nextPaymentDueDate != null &&
                  !a.details.nextPaymentDueDate!.isBefore(today),
            )
            .toList())
        ..sort(
          (a, b) => a.details.nextPaymentDueDate!.compareTo(
            b.details.nextPaymentDueDate!,
          ),
        ),
    );
    pastPaymentDates = List.unmodifiable(
      cards.where(
        (a) => a.details.nextPaymentDueDate?.isBefore(today) ?? false,
      ),
    );
    missingPaymentDates = cards
        .where((a) => a.details.nextPaymentDueDate == null)
        .length;
  }
  late final List<Account> cards;
  late final int cardsWithDebt;
  late final List<CurrencyDebt> currencies;
  late final List<Account> upcomingPayments;
  late final List<Account> pastPaymentDates;
  late final int missingPaymentDates;
  CurrencyDebt _total(
    LedgerSnapshot snapshot,
    Currency currency,
    DateTime today,
  ) {
    var debt = BigInt.zero;
    var credit = BigInt.zero;
    var future = BigInt.zero;
    var count = 0;
    for (final account in cards) {
      final value = account.balanceFor(currency)?.minorUnits ?? 0;
      if (value > 0) {
        debt += BigInt.from(value);
      }
      if (value < 0) {
        credit -= BigInt.from(value);
      }
    }
    for (final plan in snapshot.installmentPlans) {
      if (plan.draft.originalAmount.currency != currency) continue;
      for (final row in plan.pending.where((i) => i.date.isAfter(today))) {
        future += BigInt.from(row.amount.minorUnits);
        count++;
      }
    }
    return CurrencyDebt(
      debt: Money.fromBigInt(debt, currency),
      credit: Money.fromBigInt(credit, currency),
      futureInstallments: Money.fromBigInt(future, currency),
      installmentCount: count,
    );
  }
}
