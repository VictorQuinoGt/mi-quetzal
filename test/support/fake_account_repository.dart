import 'dart:async';

import 'package:mi_quetzal/data/repositories/account_repository.dart';
import 'package:mi_quetzal/domain/models/account.dart';

class FakeAccountRepository implements AccountRepository {
  final List<Account> stored = [];
  bool failLoad = false;
  bool failSave = false;
  int createCalls = 0;
  Completer<void>? saveGate;
  List<Account> Function()? currentReader;

  @override
  Future<List<Account>> getAccounts() async {
    if (failLoad) throw StateError('Fallo de lectura sintético');
    return List.unmodifiable(currentReader?.call() ?? stored);
  }

  @override
  Future<Account> createAccount(AccountDetails details) async {
    createCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Fallo de escritura sintético');
    final account = Account(id: stored.length + 1, details: details);
    stored.add(account);
    return account;
  }
}
