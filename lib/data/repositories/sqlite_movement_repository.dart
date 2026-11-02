import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/movement.dart';
import '../../domain/rules/movement_rules.dart';
import '../services/ledger_reader.dart';
import '../services/local_database.dart';
import 'movement_repository.dart';

class SqliteMovementRepository implements MovementRepository {
  SqliteMovementRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final LocalDatabase _database;
  final DateTime Function() _now;

  @override
  Future<LedgerSnapshot> getSnapshot() async {
    final db = await _database.database;
    return db.transaction(readLedger);
  }

  @override
  Future<LedgerSnapshot> createMovement(MovementDetails details) async {
    final db = await _database.database;
    return db.transaction((transaction) async {
      final previous = await readLedger(transaction);
      MovementRules.validateRegistration(details, previous.accounts, _now());
      await transaction.insert('movements', {
        'type': details.type.name,
        'account_id': details.accountId,
        'counterparty_account_id': details.counterpartyAccountId,
        'amount_minor': details.amount.minorUnits,
        'currency': details.amount.currency.name,
        'occurred_on': details.date.toIso8601String().substring(0, 10),
        'description': details.description,
      });
      // Reconstruir antes del commit valida también operaciones retroactivas.
      // Si falla, se revierte la fila completa y ambas cuentas conservan su saldo.
      return readLedger(transaction);
    });
  }
}
