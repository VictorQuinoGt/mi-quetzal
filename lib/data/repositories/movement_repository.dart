import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/movement.dart';

abstract interface class MovementRepository {
  Future<LedgerSnapshot> getSnapshot();
  Future<LedgerSnapshot> createMovement(MovementDetails details);
}
