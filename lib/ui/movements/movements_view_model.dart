import 'package:flutter/foundation.dart';

import '../../data/repositories/movement_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/movement_filter.dart';
import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import '../../domain/rules/movement_rules.dart';

enum MovementsStatus { loading, ready, error }

class MovementsViewModel extends ChangeNotifier {
  MovementsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final MovementRepository _repository;
  final DateTime Function() _now;
  LedgerSnapshot? _snapshot;
  MovementsStatus _status = MovementsStatus.loading;
  bool _saving = false;
  bool _loading = false;
  bool _disposed = false;
  Map<String, String> _fieldErrors = const {};
  String? _saveError;
  String _search = '';
  int? _accountFilter;
  MovementType? _typeFilter;
  Currency? _currencyFilter;
  DateTime? _from;
  DateTime? _to;

  String get search => _search;
  MovementFilter get filter => MovementFilter(
    query: _search,
    accountId: _accountFilter,
    type: _typeFilter,
    currency: _currencyFilter,
    from: _from,
    to: _to,
  );
  List<Movement> get visibleMovements => filter.apply(movements);
  void searchFor(String value) {
    _search = value;
    _emit();
  }

  void filterByAccount(int? id) {
    _accountFilter = id;
    _emit();
  }

  void filterByType(MovementType? type) {
    _typeFilter = type;
    _emit();
  }

  void filterByCurrency(Currency? currency) {
    _currencyFilter = currency;
    _emit();
  }

  void filterByDates(DateTime? from, DateTime? to) {
    final validated = MovementFilter(from: from, to: to);
    _from = validated.from;
    _to = validated.to;
    _emit();
  }

  void clearFilters() {
    _search = '';
    _accountFilter = null;
    _typeFilter = null;
    _currencyFilter = null;
    _from = null;
    _to = null;
    _emit();
  }

  MovementsStatus get status => _status;
  List<Account> get accounts => _snapshot?.accounts ?? const [];
  List<Movement> get movements => _snapshot?.movements ?? const [];
  List<DebitCard> get debitCards => _snapshot?.debitCards ?? const [];
  List<DebitCard> debitCardsFor(int? accountId) =>
      debitCards.where((card) => card.details.accountId == accountId).toList();
  DebitCard? debitCardById(int? id) {
    for (final card in debitCards) {
      if (card.id == id) return card;
    }
    return null;
  }

  bool get isSaving => _saving;
  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);
  String? get saveError => _saveError;
  DateTime get today {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  Account? accountById(int? id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  List<Account> originsFor(MovementType type) => accounts
      .where((account) => MovementRules.canBeOrigin(account, type))
      .toList();
  List<Account> destinationsFor(MovementType type, int? originId) {
    final origin = accountById(originId);
    return accounts
        .where(
          (account) =>
              account.id != originId &&
              account.details.openingBalance.currency ==
                  origin?.details.openingBalance.currency &&
              MovementRules.canBeDestination(account, type),
        )
        .toList();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_saving || _loading) return;
    _loading = true;
    _status = MovementsStatus.loading;
    _emit();
    try {
      _snapshot = await _repository.getSnapshot();
      _status = MovementsStatus.ready;
    } catch (_) {
      _status = MovementsStatus.error;
    } finally {
      _loading = false;
      _emit();
    }
  }

  void startCreate() {
    if (_saving) return;
    _fieldErrors = const {};
    _saveError = null;
  }

  Future<bool> createMovement({
    required MovementType type,
    required int? accountId,
    int? counterpartyAccountId,
    int? debitCardId,
    required String amount,
    required String description,
    required DateTime date,
  }) async {
    if (_saving || _status != MovementsStatus.ready) return false;
    _fieldErrors = const {};
    _saveError = null;
    MovementDetails details;
    try {
      final account = accountById(accountId);
      if (account == null) {
        throw const MovementValidationException(
          'account',
          'Selecciona una cuenta.',
        );
      }
      Money value;
      try {
        value = Money.parse(amount, account.details.openingBalance.currency);
      } on FormatException catch (error) {
        throw MovementValidationException('amount', error.message);
      }
      details = MovementDetails(
        type: type,
        accountId: account.id,
        counterpartyAccountId: counterpartyAccountId,
        debitCardId: debitCardId,
        amount: value,
        date: date,
        description: description,
      );
      MovementRules.validateRegistration(
        details,
        accounts,
        today,
        debitCards: debitCards,
      );
    } on MovementValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      _emit();
      return false;
    }
    _saving = true;
    _emit();
    try {
      _snapshot = await _repository.createMovement(details);
      return true;
    } on MovementValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      return false;
    } catch (_) {
      _saveError = 'No se pudo guardar el movimiento. El formulario se conserva; intenta de nuevo.';
      return false;
    } finally {
      _saving = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
