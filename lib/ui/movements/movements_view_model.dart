import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../../data/repositories/movement_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/account_activity.dart';
import '../../domain/models/category.dart';
import '../../domain/models/monthly_summary.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/movement_filter.dart';
import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/financial_institution.dart';
import '../../domain/models/installment_plan.dart';
import '../../domain/rules/movement_rules.dart';
import '../core/date_input.dart';

enum MovementsStatus { loading, ready, error }

class MovementsViewModel extends ChangeNotifier {
  MovementsViewModel(
    this._repository, {
    DateTime Function()? now,
    this.loadTimeout = const Duration(seconds: 15),
  }) : _now = now ?? DateTime.now {
    final date = _now();
    _summaryMonth = DateTime(date.year, date.month);
  }
  final MovementRepository _repository;
  final DateTime Function() _now;
  final Duration loadTimeout;
  LedgerSnapshot? _snapshot;
  MovementsStatus _status = MovementsStatus.loading;
  bool _saving = false;
  bool _loading = false;
  bool _disposed = false;
  int _loadGeneration = 0;
  String? _loadError;

  LedgerSnapshot? get snapshot => _snapshot;
  String? get loadError => _loadError;

  void applySnapshot(LedgerSnapshot snapshot) {
    if (_disposed || _saving) return;
    _loadGeneration++;
    _loading = false;
    _loadError = null;
    _setSnapshot(snapshot);
    _status = MovementsStatus.ready;
    _emit();
  }

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
      currency: original.details.amount.currency,
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
  List<InstallmentPlan> get installmentPlans =>
      _snapshot?.installmentPlans ?? const [];
  List<FinancialInstitution> get financialInstitutions =>
      _snapshot?.financialInstitutions ?? const [];
  FinancialInstitution? institutionById(int? id) {
    for (final value in financialInstitutions) {
      if (value.id == id) return value;
    }
    return null;
  }

  Future<bool> createFinancialInstitution(String name) async {
    if (_saving || _status != MovementsStatus.ready) return false;
    FinancialInstitutionDetails details;
    try {
      details = FinancialInstitutionDetails(name: name);
    } on FinancialInstitutionValidationException catch (error) {
      _fieldErrors = {'institutionName': error.message};
      _saveError = null;
      _emit();
      return false;
    }
    return _saveChange(
      () => _repository.createFinancialInstitution(details),
      'No se pudo crear la entidad financiera. Conservamos el nombre; intenta de nuevo.',
    );
  }

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

  Account? contextAccountFor(AccountDetailTarget? target) => target == null
      ? null
      : accountById(
          target.kind == AccountDetailKind.account
              ? target.id
              : debitCardById(target.id)?.details.accountId,
        );

  List<MovementType> operationsFor(AccountDetailTarget? target) {
    final account = contextAccountFor(target);
    return [
      for (final type in MovementType.values)
        if (type != MovementType.refund &&
            (target == null ||
                account != null &&
                    (target.kind == AccountDetailKind.debitCard
                        ? type == MovementType.expense
                        : MovementRules.canBeOrigin(account, type) ||
                              MovementRules.canBeDestination(account, type))))
          type,
    ];
  }

  ({int? accountId, int? counterpartyId, int? debitCardId, Currency? currency})
  defaultsFor(
    MovementType type,
    AccountDetailTarget? target, {
    PaymentFunding paymentFunding = PaymentFunding.account,
  }) {
    final account = contextAccountFor(target);
    final origin =
        account != null &&
        (type == MovementType.creditPayment &&
                paymentFunding == PaymentFunding.externalCash ||
            MovementRules.canBeOrigin(account, type));
    return (
      accountId: origin ? account.id : null,
      counterpartyId: account != null && !origin ? account.id : null,
      debitCardId:
          target?.kind == AccountDetailKind.debitCard &&
              type == MovementType.expense
          ? debitCardById(target!.id)?.id
          : null,
      currency: origin ? account.details.openingBalance.currency : null,
    );
  }

  List<Account> originsFor(MovementType type, {AccountDetailTarget? target}) {
    final fixedDestination = accountById(
      defaultsFor(type, target).counterpartyId,
    );
    return accounts
        .where(
          (account) =>
              MovementRules.canBeOrigin(account, type) &&
              (fixedDestination == null ||
                  fixedDestination.details.openingBalanceFor(
                        account.details.openingBalance.currency,
                      ) !=
                      null),
        )
        .toList();
  }

  List<Account> destinationsFor(MovementType type, int? originId) {
    final origin = accountById(originId);
    return accounts
        .where(
          (account) =>
              account.id != originId &&
              account.details.openingBalanceFor(
                    origin?.details.openingBalance.currency ?? Currency.gtq,
                  ) !=
                  null &&
              MovementRules.canBeDestination(account, type),
        )
        .toList();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || _saving || _loading) return;
    final generation = ++_loadGeneration;
    _loading = true;
    _loadError = null;
    if (_snapshot == null) _status = MovementsStatus.loading;
    _emit();
    try {
      final snapshot = await _repository.getSnapshot().timeout(loadTimeout);
      if (_disposed || generation != _loadGeneration) return;
      _setSnapshot(snapshot);
      _status = MovementsStatus.ready;
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      _loadError = error is TimeoutException
          ? 'La lectura está tardando demasiado. Reintenta actualizar.'
          : 'No se pudo actualizar el historial. Reintenta actualizar.';
      _status = _snapshot == null
          ? MovementsStatus.error
          : MovementsStatus.ready;
    } finally {
      if (generation == _loadGeneration) {
        _loading = false;
        _emit();
      }
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
    AccountDetailTarget? target,
    Currency? currency,
    required String amount,
    required String description,
    DateTime? date,
    String? dateInput,
    PaymentFunding paymentFunding = PaymentFunding.account,
  }) async {
    if (_saving || _status != MovementsStatus.ready) return false;
    _fieldErrors = const {};
    _saveError = null;
    MovementDetails details;
    try {
      final occurredOn = dateInput == null
          ? date
          : DateInput.tryParse(dateInput);
      if (occurredOn == null) {
        throw const MovementValidationException(
          'date',
          'Escribe una fecha válida con formato dd/mm/yyyy.',
        );
      }
      if (target != null) {
        final defaults = defaultsFor(
          type,
          target,
          paymentFunding: paymentFunding,
        );
        if (!operationsFor(target).contains(type) ||
            defaults.accountId != null && defaults.accountId != accountId ||
            defaults.counterpartyId != null &&
                defaults.counterpartyId != counterpartyAccountId ||
            defaults.debitCardId != null &&
                defaults.debitCardId != debitCardId) {
          throw const MovementValidationException(
            'account',
            'El movimiento debe corresponder a la cuenta o tarjeta seleccionada.',
          );
        }
      }
      final account = accountById(accountId);
      if (account == null) {
        throw const MovementValidationException(
          'account',
          'Selecciona una cuenta.',
        );
      }
      Money value;
      try {
        value = Money.parse(
          amount,
          currency ?? account.details.openingBalance.currency,
        );
      } on FormatException catch (error) {
        throw MovementValidationException('amount', error.message);
      }
      details = MovementDetails(
        type: type,
        accountId: account.id,
        counterpartyAccountId: counterpartyAccountId,
        debitCardId: debitCardId,
        categoryId: categoryId,
        paymentFunding: paymentFunding,
        originalMovementId: originalMovementId,
        amount: value,
        date: occurredOn,
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
      if (values.isEmpty || !values.single.details.supportsCategory) {
        throw const MovementValidationException(
          'movement',
          'Selecciona un ingreso, gasto o pago existente.',
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
    // Un resultado de lectura anterior no puede reemplazar el guardado nuevo.
    _loadGeneration++;
    _loading = false;
    _loadError = null;
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
