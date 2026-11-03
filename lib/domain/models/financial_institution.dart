final class FinancialInstitutionValidationException implements Exception {
  const FinancialInstitutionValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class FinancialInstitutionDetails {
  factory FinancialInstitutionDetails({required String name}) {
    final text = name.trim();
    if (text.isEmpty || text.length > 60) {
      throw const FinancialInstitutionValidationException(
        'Escribe un nombre de entidad de 1 a 60 caracteres.',
      );
    }
    return FinancialInstitutionDetails._(text);
  }
  const FinancialInstitutionDetails._(this.name);
  final String name;
}

final class FinancialInstitution {
  const FinancialInstitution({required this.id, required this.details});
  final int id;
  final FinancialInstitutionDetails details;
}
