import 'package:flutter/foundation.dart';

import '../../data/repositories/account_repository.dart';
import '../../domain/models/account.dart';
import '../../domain/models/money.dart';

enum AccountsStatus { loading, ready, error }

class AccountsViewModel extends ChangeNotifier {
  AccountsViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AccountRepository _repository;
  final DateTime Function() _now;
  List<Account> _accounts = const [];
  AccountsStatus _status = AccountsStatus.loading;
  bool _saving = false;
  bool _loading = false;
  bool _disposed = false;
  Map<String, String> _fieldErrors = const {};
  String? _saveError;

  List<Account> get accounts => List.unmodifiable(_accounts);
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
      _accounts = await _repository.getAccounts();
      _status = AccountsStatus.ready;
    } catch (_) {
      _status = AccountsStatus.error;
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
