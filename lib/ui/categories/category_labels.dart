import '../../domain/models/category.dart';

extension CategoryKindLabel on CategoryKind {
  String get label => switch (this) {
    CategoryKind.expense => 'Gasto',
    CategoryKind.income => 'Ingreso',
    CategoryKind.payment => 'Pago',
  };
}
