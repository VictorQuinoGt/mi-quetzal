import 'money.dart';
import 'movement.dart';

/// Consulta de presentación; nunca interviene en el cálculo de saldos.
final class MovementFilter {
  MovementFilter({
    String query = '',
    this.accountId,
    this.type,
    this.currency,
    this.categoryId,
    this.uncategorizedOnly = false,
    DateTime? from,
    DateTime? to,
  }) : query = query.trim().toLowerCase(),
       from = from == null ? null : DateTime(from.year, from.month, from.day),
       to = to == null ? null : DateTime(to.year, to.month, to.day) {
    if (this.from != null && this.to != null && this.from!.isAfter(this.to!)) {
      throw ArgumentError('El inicio no puede ser posterior al fin.');
    }
    if (categoryId != null && uncategorizedOnly) {
      throw ArgumentError(
        'Selecciona una categoría o sin categoría, no ambos.',
      );
    }
  }
  final String query;
  final int? accountId;
  final MovementType? type;
  final Currency? currency;
  final int? categoryId;
  final bool uncategorizedOnly;
  final DateTime? from;
  final DateTime? to;
  bool get isActive =>
      query.isNotEmpty ||
      accountId != null ||
      type != null ||
      currency != null ||
      categoryId != null ||
      uncategorizedOnly ||
      from != null ||
      to != null;

  List<Movement> apply(List<Movement> movements) {
    final byId = {for (final movement in movements) movement.id: movement};
    return List.unmodifiable(
      movements.where((movement) {
        final data = movement.details;
        final effectiveCategory = data.isRefund
            ? byId[data.originalMovementId]?.details.categoryId
            : data.categoryId;
        return (query.isEmpty ||
                data.description.toLowerCase().contains(query)) &&
            (accountId == null ||
                data.accountId == accountId ||
                data.counterpartyAccountId == accountId) &&
            (type == null || data.type == type) &&
            (currency == null || data.amount.currency == currency) &&
            (categoryId == null || effectiveCategory == categoryId) &&
            (!uncategorizedOnly ||
                effectiveCategory == null &&
                    (data.isExpense || data.isIncome || data.isRefund)) &&
            (from == null || !data.date.isBefore(from!)) &&
            (to == null || !data.date.isAfter(to!));
      }),
    );
  }
}
