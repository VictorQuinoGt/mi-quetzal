import 'ledger_snapshot.dart';
import 'money.dart';

final class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.amount,
  });
  final int? categoryId;
  final String name;
  final Money amount;
}

final class CurrencyMonthlySummary {
  const CurrencyMonthlySummary({
    required this.currency,
    required this.income,
    required this.expense,
    required this.difference,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });
  final Currency currency;
  final Money income;
  final Money expense;
  final Money difference;
  final List<CategoryTotal> incomeByCategory;
  final List<CategoryTotal> expenseByCategory;
}

final class MonthlySummary {
  factory MonthlySummary.calculate(LedgerSnapshot ledger, int year, int month) {
    if (year < 1 || year > 9999 || month < 1 || month > 12) {
      throw ArgumentError('Mes no válido.');
    }
    final result = <CurrencyMonthlySummary>[];
    final byId = {for (final m in ledger.movements) m.id: m};
    final labels = {
      for (final category in ledger.categories)
        category.id: category.details.name,
    };
    for (final currency in Currency.values) {
      var income = BigInt.zero;
      var expense = BigInt.zero;
      final incomeGroups = <int?, BigInt>{};
      final expenseGroups = <int?, BigInt>{};
      for (final movement in ledger.movements) {
        final data = movement.details;
        if (data.reconciledIntoId != null) continue;
        if (data.date.year != year ||
            data.date.month != month ||
            data.amount.currency != currency) {
          continue;
        }
        if (!data.isExpense && !data.isIncome && !data.isRefund) continue;
        final value =
            BigInt.from(
              data.isExpense
                  ? data.reportExpense.minorUnits
                  : data.amount.minorUnits,
            ) *
            (data.isRefund ? -BigInt.one : BigInt.one);
        final categoryId = data.isRefund
            ? byId[data.originalMovementId]!.details.categoryId
            : data.categoryId;
        final groups = data.isIncome ? incomeGroups : expenseGroups;
        groups[categoryId] = (groups[categoryId] ?? BigInt.zero) + value;
        if (data.isIncome) {
          income += value;
        } else {
          expense += value;
        }
      }
      if (incomeGroups.isEmpty && expenseGroups.isEmpty) continue;
      List<CategoryTotal> totals(Map<int?, BigInt> groups) {
        final values = groups.entries
            .map(
              (entry) => CategoryTotal(
                categoryId: entry.key,
                name: entry.key == null ? 'Sin categoría' : labels[entry.key]!,
                amount: Money.fromBigInt(entry.value, currency),
              ),
            )
            .toList();
        values.sort((a, b) {
          final amountOrder = b.amount.minorUnits.compareTo(
            a.amount.minorUnits,
          );
          return amountOrder == 0
              ? (a.categoryId ?? 0).compareTo(b.categoryId ?? 0)
              : amountOrder;
        });
        return List.unmodifiable(values);
      }

      result.add(
        CurrencyMonthlySummary(
          currency: currency,
          income: Money.fromBigInt(income, currency),
          expense: Money.fromBigInt(expense, currency),
          difference: Money.fromBigInt(income - expense, currency),
          incomeByCategory: totals(incomeGroups),
          expenseByCategory: totals(expenseGroups),
        ),
      );
    }
    return MonthlySummary._(year, month, List.unmodifiable(result));
  }
  const MonthlySummary._(this.year, this.month, this.currencies);
  final int year;
  final int month;
  final List<CurrencyMonthlySummary> currencies;
}
