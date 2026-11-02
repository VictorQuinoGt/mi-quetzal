import 'dart:async';

import 'package:mi_quetzal/data/repositories/movement_repository.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/rules/movement_rules.dart';

import 'fake_account_repository.dart';

class FakeMovementRepository implements MovementRepository {
  FakeMovementRepository(this.accounts) {
    accounts.currentReader = () => snapshot.accounts;
  }
  final FakeAccountRepository accounts;
  final List<Movement> stored = [];
  bool failLoad = false;
  bool failSave = false;
  int createCalls = 0;
  Completer<void>? saveGate;
  LedgerSnapshot get snapshot =>
      LedgerSnapshot.calculate(accounts.stored, stored);

  @override
  Future<LedgerSnapshot> getSnapshot() async {
    if (failLoad) throw StateError('Fallo de lectura sintético');
    return snapshot;
  }

  @override
  Future<LedgerSnapshot> createMovement(MovementDetails details) async {
    createCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Fallo de escritura sintético');
    MovementRules.validateRegistration(
      details,
      accounts.stored,
      DateTime.now(),
    );
    final movement = Movement(id: stored.length + 1, details: details);
    final next = LedgerSnapshot.calculate(accounts.stored, [
      ...stored,
      movement,
    ]);
    stored.add(movement);
    return next;
  }
}
