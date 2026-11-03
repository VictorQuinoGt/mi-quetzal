import 'package:flutter/foundation.dart';

import '../../data/repositories/movement_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/account_activity.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/money.dart';
import '../../domain/models/installment_plan.dart';
import '../movements/movements_view_model.dart';

enum AccountPeriod { currentMonth, previousMonth, history }

class AccountDetailViewModel extends ChangeNotifier {
  AccountDetailViewModel(
    MovementRepository repository, {
    required this.target,
    this.initialName = 'Detalle de cuenta',
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       ledger = MovementsViewModel(repository, now: now) {
    _historyMonth = DateTime(today.year, today.month);
    ledger.addListener(notifyListeners);
  }
  final AccountDetailTarget target;
  final String initialName;
  final DateTime Function() _now;
  final MovementsViewModel ledger;
  AccountPeriod _period = AccountPeriod.currentMonth;
  bool _showInstallments = false;
  bool get showInstallments => _showInstallments;
  void selectInstallments(bool value) {
    _showInstallments = value;
    notifyListeners();
  }

  List<InstallmentPlan> get plans => ledger.installmentPlans
      .where((p) => p.draft.accountId == account?.id)
      .toList();
  String shortDate(DateTime? date) => date == null
      ? 'Sin configurar'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  late DateTime _historyMonth;
  DateTime get today {
    final date = _now();
    return DateTime(date.year, date.month, date.day);
  }

  AccountPeriod get period => _period;
  DateTime get selectedMonth => switch (_period) {
    AccountPeriod.currentMonth => DateTime(today.year, today.month),
    AccountPeriod.previousMonth => DateTime(today.year, today.month - 1),
    AccountPeriod.history => _historyMonth,
  };
  int get latestYear => today.year;
  List<int> get availableMonths => [
    for (
      var month = 1;
      month <= (_historyMonth.year == today.year ? today.month : 12);
      month++
    )
      month,
  ];
  void selectPeriod(AccountPeriod value) {
    _period = value;
    notifyListeners();
  }

  void selectHistory(int year, int month) {
    if (year < 1900 ||
        year > today.year ||
        month < 1 ||
        month > 12 ||
        DateTime(year, month).isAfter(DateTime(today.year, today.month))) {
      throw ArgumentError(
        'Selecciona un mes entre enero de 1900 y el mes actual.',
      );
    }
    _historyMonth = DateTime(year, month);
    _period = AccountPeriod.history;
    notifyListeners();
  }

  void selectHistoryYear(int year) => selectHistory(
    year,
    year == today.year && selectedMonth.month > today.month
        ? today.month
        : selectedMonth.month,
  );
  DebitCard? get debitCard => target.kind == AccountDetailKind.debitCard
      ? ledger.debitCardById(target.id)
      : null;
  Account? get account => ledger.accountById(
    target.kind == AccountDetailKind.account
        ? target.id
        : debitCard?.details.accountId,
  );
  List<DebitCard> get linkedDebitCards => ledger.debitCardsFor(account?.id);
  String get name =>
      debitCard?.details.name ?? account?.details.name ?? initialName;
  String? get institution => ledger
      .institutionById(
        debitCard?.details.financialInstitutionId ??
            account?.details.financialInstitutionId,
      )
      ?.details
      .name;
  String? get lastFour =>
      debitCard?.details.lastFour ??
      (target.kind == AccountDetailKind.account
          ? account?.details.lastFour
          : null);
  List<Money> get availableCredits => [
    if (account != null)
      for (final balance in account!.currentBalances)
        ?account!.availableCreditFor(balance.currency),
  ];
  List<String> get limitLabels => [
    if (account != null)
      for (final balance in account!.currentBalances)
        account!.creditLimitFor(balance.currency)?.compact ??
            '${balance.currency == Currency.gtq ? 'Q' : 'US\$'}: Sin configurar',
  ];
  List<String> get availableLabels => [
    if (account != null)
      for (final balance in account!.currentBalances)
        account!.availableCreditFor(balance.currency)?.compact ??
            '${balance.currency == Currency.gtq ? 'Q' : 'US\$'}: Sin determinar',
  ];
  AccountActivity? get activity => account == null
      ? null
      : AccountActivity(
          accountId: account!.id,
          movements: ledger.movements,
          debitCardId: debitCard?.id,
        );
  List<Movement> get movements => activity?.inMonth(selectedMonth) ?? const [];
  String? get debitScope => debitCard == null
      ? null
      : activity!.identifiesDebitCards
      ? 'Solo movimientos identificados con esta tarjeta y sus devoluciones. El saldo es el de la cuenta bancaria vinculada.'
      : 'Movimientos de la cuenta bancaria vinculada: aún no hay operaciones identificadas por tarjeta. El saldo pertenece a esa cuenta.';
  bool isPast(DateTime date) => date.isBefore(today);
  Future<void> load() => ledger.load();
  @override
  void dispose() {
    ledger.removeListener(notifyListeners);
    ledger.dispose();
    super.dispose();
  }
}
