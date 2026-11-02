import '../../domain/models/category.dart';

extension CategoryKindLabel on CategoryKind {
  String get label => this == CategoryKind.expense ? 'Gasto' : 'Ingreso';
}
