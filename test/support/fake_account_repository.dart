import 'dart:async';

import 'package:mi_quetzal/data/repositories/account_repository.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/rules/account_rules.dart';

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
  void Function(List<Account>)? validateAccounts;
  void Function(int, DebitCardDetails)? validateDebitUpdate;
  int updateCalls = 0;
  int updateCardCalls = 0;

  @override
  Future<Account> updateAccount(int id, AccountDetails details) async {
    updateCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Fallo de escritura sintético');
    final index = stored.indexWhere((a) => a.id == id);
    if (index < 0) throw ArgumentError('La cuenta ya no existe.', 'name');
    AccountRules.validateUpdate(stored[index], details);
    final updated = Account(id: id, details: details);
    final next = [...stored]..[index] = updated;
    validateAccounts?.call(next);
    stored[index] = updated;
    return (currentReader?.call() ?? stored).singleWhere((a) => a.id == id);
  }

  @override
  Future<DebitCard> updateDebitCard(int id, DebitCardDetails details) async {
    updateCardCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Fallo de escritura sintético');
    final index = cards.indexWhere((c) => c.id == id);
    if (index < 0) {
      throw const DebitCardValidationException(
        'name',
        'La tarjeta ya no existe.',
      );
    }
    details.validateAccount(stored);
    validateDebitUpdate?.call(id, details);
    final updated = DebitCard(id: id, details: details);
    cards[index] = updated;
    return updated;
  }

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
