import 'movement.dart';

enum CategoryKind { expense, income }

final class CategoryValidationException implements Exception {
  const CategoryValidationException(this.field, this.message);
  final String field;
  final String message;
  @override
  String toString() => message;
}

final class CategoryDetails {
  factory CategoryDetails({required String name, required CategoryKind kind}) {
    final alias = name.trim();
    if (alias.isEmpty || alias.length > 60) {
      throw const CategoryValidationException(
        'name',
        'Escribe un nombre de 1 a 60 caracteres.',
      );
    }
    return CategoryDetails._(alias, kind);
  }
  const CategoryDetails._(this.name, this.kind);
  final String name;
  final CategoryKind kind;
  bool supports(MovementType type) =>
      kind == CategoryKind.expense && type == MovementType.expense ||
      kind == CategoryKind.income && type == MovementType.income;
}

final class Category {
  const Category({required this.id, required this.details});
  final int id;
  final CategoryDetails details;
}
