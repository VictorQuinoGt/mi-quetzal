import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/category.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/financial_institution.dart';

enum MovementStorageFailure {
  structure('BD-ESTRUCTURA'),
  busy('BD-OCUPADA'),
  full('BD-ESPACIO'),
  readOnly('BD-LECTURA'),
  connection('BD-CONEXION'),
  unknown('BD-GUARDADO');

  const MovementStorageFailure(this.code);
  final String code;
}

/// Diagnóstico estable sin SQL, argumentos ni información financiera del usuario.
final class MovementStorageException implements Exception {
  const MovementStorageException(this.failure);
  final MovementStorageFailure failure;
  @override
  String toString() => failure.code;
}

abstract interface class MovementRepository {
  Future<LedgerSnapshot> getSnapshot();
  Future<LedgerSnapshot> createFinancialInstitution(
    FinancialInstitutionDetails details,
  );
  Future<LedgerSnapshot> createMovement(MovementDetails details);
  Future<LedgerSnapshot> createCategory(CategoryDetails details);
  Future<LedgerSnapshot> assignCategory(int movementId, int? categoryId);
}
