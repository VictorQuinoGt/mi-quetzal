import 'package:flutter/foundation.dart' hide Category;

import '../../data/repositories/movement_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/category.dart';
import '../../domain/models/monthly_summary.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/movement_filter.dart';
import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import '../../domain/rules/movement_rules.dart';

enum MovementsStatus { loading, ready, error }

class MovementsViewModel extends ChangeNotifier {
  MovementsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    final date = _now();
    _summaryMonth = DateTime(date.year, date.month);
  }
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
  int? _categoryFilter;
  bool _uncategorizedOnly = false;
  late DateTime _summaryMonth;
  MonthlySummary? _summary;
  String? _summaryError;

  DateTime get summaryMonth => _summaryMonth;
  MonthlySummary? get summary => _summary;
  String? get summaryError => _summaryError;
  bool get canGoToPreviousMonth => _summaryMonth.isAfter(DateTime(1900));
  bool get canGoToNextMonth =>
      _summaryMonth.isBefore(DateTime(today.year, today.month));
  void previousSummaryMonth() {
    if (canGoToPreviousMonth) {
      selectSummaryMonth(DateTime(_summaryMonth.year, _summaryMonth.month - 1));
    }
  }

  void nextSummaryMonth() {
    if (canGoToNextMonth) {
      selectSummaryMonth(DateTime(_summaryMonth.year, _summaryMonth.month + 1));
    }
  }

  void selectSummaryMonth(DateTime date) {
    final month = DateTime(date.year, date.month);
    if (month.isBefore(DateTime(1900)) ||
        month.isAfter(DateTime(today.year, today.month))) {
      throw ArgumentError(
        'Selecciona un mes entre enero de 1900 y el mes actual.',
      );
    }
    _summaryMonth = month;
    _refreshSummary();
    _emit();
  }

  void _setSnapshot(LedgerSnapshot snapshot) {
    _snapshot = snapshot;
    _refreshSummary();
  }

  void _refreshSummary() {
    _summary = null;
    _summaryError = null;
    final snapshot = _snapshot;
    if (snapshot == null) return;
    try {
      _summary = MonthlySummary.calculate(
        snapshot,
        _summaryMonth.year,
        _summaryMonth.month,
      );
    } on ArgumentError {
      _summaryError = 'Los totales del mes superan el rango admitido. Consulta los movimientos por cuenta.';
    }
  }

  String get search => _search;
  MovementFilter get filter => MovementFilter(
    query: _search,
    accountId: _accountFilter,
    type: _typeFilter,
    currency: _currencyFilter,
    from: _from,
    to: _to,
    categoryId: _categoryFilter,
    uncategorizedOnly: _uncategorizedOnly,
  );
  List<Movement> get visibleMovements => filter.apply(movements);
  Movement? movementById(int? id) {
    for (final movement in movements) {
      if (movement.id == id) return movement;
    }
    return null;
  }

  Money remainingRefund(Movement original) =>
      MovementRules.remainingRefund(original, movements);

  int? categoryIdFor(Movement movement) => movement.details.isRefund
      ? movementById(movement.details.originalMovementId)?.details.categoryId
      : movement.details.categoryId;

  Future<bool> refundPurchase({
    required int originalMovementId,
    required String amount,
    required String description,
    required DateTime date,
  }) async {
    final original = movementById(originalMovementId);
    if (original == null || !original.details.isExpense) {
      if (_saving || _status != MovementsStatus.ready) return false;
      _fieldErrors = const {
        'originalMovement': 'Selecciona una compra o gasto existente.',
      };
      _emit();
      return false;
    }
    return createMovement(
      type: MovementType.refund,
      originalMovementId: originalMovementId,
      accountId: original.details.accountId,
      amount: amount,
      description: description,
      date: date,
    );
  }

  void filterByCategory(int? id, {bool uncategorizedOnly = false}) {
    MovementFilter(categoryId: id, uncategorizedOnly: uncategorizedOnly);
    _categoryFilter = id;
    _uncategorizedOnly = uncategorizedOnly;
    _emit();
  }

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
    _categoryFilter = null;
    _uncategorizedOnly = false;
    _emit();
  }

  MovementsStatus get status => _status;
  List<Account> get accounts => _snapshot?.accounts ?? const [];
  List<Movement> get movements => _snapshot?.movements ?? const [];
  List<Category> get categories => _snapshot?.categories ?? const [];
  List<Category> categoriesFor(MovementType type) =>
      categories.where((category) => category.details.supports(type)).toList();
  Category? categoryById(int? id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

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
      _setSnapshot(await _repository.getSnapshot());
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
    int? categoryId,
    int? originalMovementId,
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
        categoryId: categoryId,
        originalMovementId: originalMovementId,
        amount: value,
        date: date,
        description: description,
      );
      MovementRules.validateRegistration(
        details,
        accounts,
        today,
        debitCards: debitCards,
        categories: categories,
        movements: movements,
      );
    } on MovementValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      _emit();
      return false;
    }
    return _saveChange(
      () => _repository.createMovement(details),
      'No se pudo guardar el movimiento. El formulario se conserva; intenta de nuevo.',
    );
  }

  Future<bool> createCategory({
    required String name,
    required CategoryKind kind,
  }) async {
    if (_saving || _status != MovementsStatus.ready) return false;
    _fieldErrors = const {};
    _saveError = null;
    CategoryDetails details;
    try {
      details = CategoryDetails(name: name, kind: kind);
    } on CategoryValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      _emit();
      return false;
    }
    return _saveChange(
      () => _repository.createCategory(details),
      'No se pudo crear la categoría. Conservamos el formulario; intenta de nuevo.',
    );
  }

  Future<bool> assignCategory(int movementId, int? categoryId) async {
    if (_saving || _status != MovementsStatus.ready) return false;
    _fieldErrors = const {};
    _saveError = null;
    try {
      final values = movements.where((m) => m.id == movementId);
      if (values.isEmpty ||
          !(values.single.details.isExpense ||
              values.single.details.isIncome)) {
        throw const MovementValidationException(
          'movement',
          'Selecciona un ingreso o gasto existente.',
        );
      }
      MovementRules.effects(
        values.single.details.withCategory(categoryId),
        accounts,
        debitCards: debitCards,
        categories: categories,
      );
    } on MovementValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      _emit();
      return false;
    }
    return _saveChange(
      () => _repository.assignCategory(movementId, categoryId),
      'No se pudo actualizar la categoría. Conservamos tu selección; intenta de nuevo.',
    );
  }

  Future<bool> _saveChange(
    Future<LedgerSnapshot> Function() action,
    String failure,
  ) async {
    if (_saving || _status != MovementsStatus.ready) return false;
    _fieldErrors = const {};
    _saveError = null;
    _saving = true;
    _emit();
    try {
      _setSnapshot(await action());
      return true;
    } on MovementValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      return false;
    } on CategoryValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      return false;
    } catch (_) {
      _saveError = failure;
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
