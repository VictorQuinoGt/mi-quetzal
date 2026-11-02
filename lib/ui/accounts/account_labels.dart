import '../../domain/models/account.dart';

extension AccountTypeLabel on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Efectivo',
    AccountType.bank => 'Cuenta bancaria',
    AccountType.creditCard => 'Tarjeta de crédito',
  };
}
