import 'dart:async';

import 'package:mi_quetzal/data/repositories/movement_repository.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/category.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/rules/movement_rules.dart';

import 'fake_account_repository.dart';

class FakeMovementRepository implements MovementRepository {
  FakeMovementRepository(this.accounts) {
    accounts.currentReader = () => snapshot.accounts;
  }
  final FakeAccountRepository accounts;
  final List<Movement> stored = [];
  final List<Category> categories = [];
  int createCategoryCalls = 0;
  int assignCategoryCalls = 0;
  bool failLoad = false;
  bool failSave = false;
  int createCalls = 0;
  Completer<void>? saveGate;
  LedgerSnapshot get snapshot => LedgerSnapshot.calculate(
    accounts.stored,
    stored,
    debitCards: accounts.cards,
    categories: categories,
  );

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
      debitCards: accounts.cards,
      categories: categories,
      movements: stored,
    );
    final movement = Movement(id: stored.length + 1, details: details);
    final next = LedgerSnapshot.calculate(
      accounts.stored,
      [...stored, movement],
      debitCards: accounts.cards,
      categories: categories,
    );
    stored.add(movement);
    return next;
  }

  @override
  Future<LedgerSnapshot> createCategory(CategoryDetails details) async {
    createCategoryCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Fallo de escritura sintético');
    categories.add(Category(id: categories.length + 1, details: details));
    return snapshot;
  }

  @override
  Future<LedgerSnapshot> assignCategory(int movementId, int? categoryId) async {
    assignCategoryCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Fallo de escritura sintético');
    final index = stored.indexWhere((m) => m.id == movementId);
    if (index < 0 ||
        !(stored[index].details.isExpense || stored[index].details.isIncome)) {
      throw const MovementValidationException(
        'movement',
        'Selecciona un ingreso o gasto existente.',
      );
    }
    final updated = Movement(
      id: movementId,
      details: stored[index].details.withCategory(categoryId),
    );
    final values = [...stored]..[index] = updated;
    final next = LedgerSnapshot.calculate(
      accounts.stored,
      values,
      debitCards: accounts.cards,
      categories: categories,
    );
    stored[index] = updated;
    return next;
  }
}
