import 'dart:async';

import 'package:mi_quetzal/data/repositories/account_repository.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';

class FakeAccountRepository implements AccountRepository {
  final List<Account> stored = [];
  final List<DebitCard> cards = [];
  int createCardCalls = 0;

  @override
  Future<List<DebitCard>> getDebitCards() async {
    if (failLoad) throw StateError('Fallo de lectura sintético');
    return List.unmodifiable(cards);
  }

  @override
  Future<DebitCard> createDebitCard(DebitCardDetails details) async {
    createCardCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Fallo de escritura sintético');
    details.validateAccount(stored);
    final card = DebitCard(id: cards.length + 1, details: details);
    cards.add(card);
    return card;
  }

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
