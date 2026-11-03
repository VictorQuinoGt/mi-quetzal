import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/category.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/financial_institution.dart';

abstract interface class MovementRepository {
  Future<LedgerSnapshot> getSnapshot();
  Future<LedgerSnapshot> createFinancialInstitution(
    FinancialInstitutionDetails details,
  );
  Future<LedgerSnapshot> createMovement(MovementDetails details);
  Future<LedgerSnapshot> createCategory(CategoryDetails details);
  Future<LedgerSnapshot> assignCategory(int movementId, int? categoryId);
}
