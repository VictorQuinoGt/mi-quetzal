import 'package:flutter/foundation.dart';

import '../../data/repositories/account_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/money.dart';

enum AccountsStatus { loading, ready, error }

class AccountsViewModel extends ChangeNotifier {
  AccountsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AccountRepository _repository;
  final DateTime Function() _now;
  List<Account> _accounts = const [];
  List<DebitCard> _debitCards = const [];
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
      _accounts = await _repository.getAccounts();
      _debitCards = cards;
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
      );
      details.validateAccount(accounts);
    } on DebitCardValidationException catch (error) {
      _fieldErrors = {error.field: error.message};
      _emit();
      return false;
    }
    _saving = true;
    _emit();
    try {
      final card = await _repository.createDebitCard(details);
      _debitCards = [..._debitCards, card];
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
  }) async {
    if (_saving || _status != AccountsStatus.ready) return false;
    final errors = <String, String>{};
    Money? parse(String value, String field) {
      try {
        return Money.parse(value, currency);
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
          lastFour: type == AccountType.creditCard ? lastFour : null,
        );
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
      final account = await _repository.createAccount(details);
      _accounts = [..._accounts, account];
      return true;
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
