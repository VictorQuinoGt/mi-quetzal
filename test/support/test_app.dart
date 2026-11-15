import 'package:mi_quetzal/app/mi_quetzal_app.dart';
import 'package:mi_quetzal/app/appearance_view_model.dart';

import 'fake_account_repository.dart';
import 'fake_movement_repository.dart';
import 'fake_installment_repository.dart';
import 'fake_settings_repository.dart';

MiQuetzalApp testApp({
  FakeAccountRepository? repository,
  FakeMovementRepository? movements,
  AppearanceViewModel? appearance,
}) {
  final accounts = repository ?? FakeAccountRepository();
  final ledger = movements ?? FakeMovementRepository(accounts);
  return MiQuetzalApp(
    accountRepository: accounts,
    movementRepository: ledger,
    installmentRepository: FakeInstallmentRepository(ledger),
    appearanceViewModel:
        appearance ?? AppearanceViewModel(FakeSettingsRepository()),
  );
}
