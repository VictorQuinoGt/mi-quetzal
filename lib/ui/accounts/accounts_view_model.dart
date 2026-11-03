import 'package:flutter/foundation.dart';

import '../../data/repositories/account_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/financial_institution.dart';

enum AccountsStatus { loading, ready, error }

class AccountsViewModel extends ChangeNotifier {
  AccountsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AccountRepository _repository;
  final DateTime Function() _now;
  List<Account> _accounts = const [];
  List<DebitCard> _debitCards = const [];
  List<FinancialInstitution> _financialInstitutions = const [];
  List<FinancialInstitution> get financialInstitutions =>
      List.unmodifiable(_financialInstitutions);
  FinancialInstitution? institutionById(int? id) {
    for (final value in _financialInstitutions) {
      if (value.id == id) return value;
    }
    return null;
  }

  AccountsStatus _status = AccountsStatus.loading;
  bool _saving = false;
  bool _loading = false;
  bool _disposed = false;
  Map<String, String> _fieldErrors = const {};
  String? _saveError;

  List<Account> get accounts => List.unmodifiable(_accounts);
  List<DebitCard> get debitCards => List.unmodifiable(_debitCards);
  List<Account> get bankAccounts =>
      accounts.where((a) => a.details.type == AccountType.bank).toList();
  Account? accountById(int id) {
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  AccountsStatus get status => _status;
  bool get isSaving => _saving;
  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);
  String? get saveError => _saveError;
  DateTime get today {
    final date = _now();
    return DateTime(date.year, date.month, date.day);
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_loading || _saving) return;
    _loading = true;
    _status = AccountsStatus.loading;
    _emit();
    try {
      final cards = await _repository.getDebitCards();
      final institutions = await _repository.getFinancialInstitutions();
      _accounts = await _repository.getAccounts();
      _debitCards = cards;
      _financialInstitutions = institutions;
      _status = AccountsStatus.ready;
    } catch (_) {
      _status = AccountsStatus.error;
    } finally {
      _loading = false;
      _emit();
    }
  }

  Future<bool> createDebitCard({
    required String name,
    required int? accountId,
    String lastFour = '',
  }) => saveDebitCard(name: name, accountId: accountId, lastFour: lastFour);

  Future<bool> saveDebitCard({
    int? editingId,
    int? financialInstitutionId,
    required String name,
    required int? accountId,
    String lastFour = '',
  }) async {
    if (_saving || _status != AccountsStatus.ready) return false;
    _fieldErrors = const {};
    _saveError = null;
    DebitCardDetails details;
    try {
      details = DebitCardDetails(
        name: name,
        accountId: accountId ?? 0,
        lastFour: lastFour,
        financialInstitutionId: financialInstitutionId,
      );
      details.validateAccount(accounts);
      details.validateFinancialInstitution(financialInstitutions);
    } on DebitCardValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      _emit();
      return false;
    }
    _saving = true;
    _emit();
    try {
      final card = editingId == null
          ? await _repository.createDebitCard(details)
          : await _repository.updateDebitCard(editingId, details);
      _debitCards = editingId == null
          ? [..._debitCards, card]
          : [
              for (final current in _debitCards)
                current.id == editingId ? card : current,
            ];
      return true;
    } on DebitCardValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      return false;
    } catch (_) {
      _saveError = 'No se pudo guardar la tarjeta. El formulario se conserva; intenta de nuevo.';
      return false;
    } finally {
      _saving = false;
      _emit();
    }
  }

  void startCreate() {
    if (_saving) return;
    _fieldErrors = const {};
    _saveError = null;
  }

  Future<bool> createAccount({
    required String name,
    required AccountType type,
    required Currency currency,
    required String openingBalance,
    required DateTime openingDate,
    String creditLimit = '',
    String lastFour = '',
  }) => saveAccount(
    name: name,
    type: type,
    currency: currency,
    openingBalance: openingBalance,
    openingDate: openingDate,
    creditLimit: creditLimit,
    lastFour: lastFour,
  );

  Future<bool> saveAccount({
    int? editingId,
    int? financialInstitutionId,
    required String name,
    required AccountType type,
    required Currency currency,
    required String openingBalance,
    required DateTime openingDate,
    String creditLimit = '',
    String lastFour = '',
    BankAccountType? bankAccountType,
    String secondaryOpeningBalance = '',
    String secondaryCreditLimit = '',
  }) async {
    if (_saving || _status != AccountsStatus.ready) return false;
    final errors = <String, String>{};
    Money? parse(String value, String field, [Currency? inCurrency]) {
      try {
        return Money.parse(value, inCurrency ?? currency);
      } on FormatException catch (error) {
        errors[field] = error.message;
        return null;
      }
    }

    final balance = parse(openingBalance, 'openingBalance');
    final limit =
        type == AccountType.creditCard && creditLimit.trim().isNotEmpty
        ? parse(creditLimit, 'creditLimit')
        : null;
    final otherCurrency = currency == Currency.gtq
        ? Currency.usd
        : Currency.gtq;
    final secondaryBalance =
        type == AccountType.creditCard &&
            secondaryOpeningBalance.trim().isNotEmpty
        ? parse(
            secondaryOpeningBalance,
            'secondaryOpeningBalance',
            otherCurrency,
          )
        : null;
    final secondaryLimit =
        type == AccountType.creditCard && secondaryCreditLimit.trim().isNotEmpty
        ? parse(secondaryCreditLimit, 'secondaryCreditLimit', otherCurrency)
        : null;
    AccountDetails? details;
    if (openingDate.isAfter(today)) {
      errors['openingDate'] =
          'El saldo inicial no puede tener una fecha futura.';
    }
    if (balance != null) {
      try {
        details = AccountDetails(
          name: name,
          type: type,
          openingBalance: balance,
          openingDate: openingDate,
          creditLimit: limit,
          lastFour: type != AccountType.cash ? lastFour : null,
          financialInstitutionId: type != AccountType.cash
              ? financialInstitutionId
              : null,
          bankAccountType: type == AccountType.bank ? bankAccountType : null,
          secondaryOpeningBalance: secondaryBalance,
          secondaryCreditLimit: secondaryLimit,
        );
        details.validateFinancialInstitution(financialInstitutions);
      } on ArgumentError catch (error) {
        errors[error.name ?? 'name'] = error.message as String;
      }
    }
    _fieldErrors = errors;
    _saveError = null;
    if (errors.isNotEmpty || details == null) {
      _emit();
      return false;
    }
    _saving = true;
    _emit();
    try {
      final account = editingId == null
          ? await _repository.createAccount(details)
          : await _repository.updateAccount(editingId, details);
      _accounts = editingId == null
          ? [..._accounts, account]
          : [
              for (final current in _accounts)
                current.id == editingId ? account : current,
            ];
      return true;
    } on ArgumentError catch (error) {
      _fieldErrors = {error.name ?? 'name': error.message.toString()};
      return false;
    } on MovementValidationException catch (error) {
      _fieldErrors = {
        error.field == 'date' ? 'openingDate' : 'openingBalance': error.message,
      };
      return false;
    } catch (_) {
      _saveError = 'No se pudo guardar la cuenta. Tus datos del formulario se conservan; intenta de nuevo.';
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
