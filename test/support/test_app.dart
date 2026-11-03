import 'package:mi_quetzal/app/mi_quetzal_app.dart';

import 'fake_account_repository.dart';
import 'fake_movement_repository.dart';
import 'fake_installment_repository.dart';

MiQuetzalApp testApp({
  FakeAccountRepository? repository,
  FakeMovementRepository? movements,
}) {
  final accounts = repository ?? FakeAccountRepository();
  final ledger = movements ?? FakeMovementRepository(accounts);
  return MiQuetzalApp(
    accountRepository: accounts,
    movementRepository: ledger,
    installmentRepository: FakeInstallmentRepository(ledger),
  );
}
