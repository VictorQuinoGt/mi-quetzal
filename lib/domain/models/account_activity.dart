import 'movement.dart';
import 'movement_filter.dart';

enum AccountDetailKind { account, debitCard }

final class AccountDetailTarget {
  const AccountDetailTarget.account(this.id) : kind = AccountDetailKind.account;
  const AccountDetailTarget.debitCard(this.id)
    : kind = AccountDetailKind.debitCard;
  final int id;
  final AccountDetailKind kind;
}

/// Mes calendario, independiente de los ciclos de corte de crédito.
final class AccountActivity {
  AccountActivity({
    required this.accountId,
    required List<Movement> movements,
    this.debitCardId,
  }) : _movements = List.unmodifiable(movements) {
    final associated = MovementFilter(accountId: accountId).apply(_movements);
    identifiesDebitCards =
        debitCardId != null &&
        associated.any((m) => m.details.debitCardId != null);
  }
  final int accountId;
  final int? debitCardId;
  final List<Movement> _movements;
  late final bool identifiesDebitCards;

  List<Movement> inMonth(DateTime month) {
    final rows = MovementFilter(
      accountId: accountId,
      from: DateTime(month.year, month.month),
      to: DateTime(month.year, month.month + 1, 0),
    ).apply(_movements);
    if (!identifiesDebitCards) return rows;
    final byId = {for (final movement in _movements) movement.id: movement};
    return List.unmodifiable(
      rows.where(
        (m) =>
            m.details.debitCardId == debitCardId ||
            m.details.isRefund &&
                byId[m.details.originalMovementId]?.details.debitCardId ==
                    debitCardId,
      ),
    );
  }
}
