import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/financial_institution.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/ui/accounts/accounts_view_model.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_movement_repository.dart';

void main() {
  test('ViewModel carga catálogo, valida referencias y conserva entidad y terminación al editar', () async {
    final accounts = FakeAccountRepository();
    final movements = FakeMovementRepository(accounts);
    await movements.createFinancialInstitution(
      FinancialInstitutionDetails(name: 'Entidad sintética'),
    );
    final vm = AccountsViewModel(accounts, now: () => DateTime(2026, 11, 2));
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.financialInstitutions.single.details.name, 'Entidad sintética');
    Future<bool> save(int institution, {int? id}) => vm.saveAccount(
      editingId: id,
      name: 'Banco sintético',
      type: AccountType.bank,
      currency: vm.accounts.isEmpty
          ? Currency.gtq
          : vm.accounts.single.currentBalance.currency,
      openingBalance: '0.29',
      openingDate: DateTime(2026, 10, 1),
      lastFour: '0042',
      financialInstitutionId: institution,
    );
    expect(await save(999), isFalse);
    expect(vm.fieldErrors, contains('financialInstitution'));
    expect(accounts.createCalls, 0);
    expect(await save(1), isTrue);
    expect(await save(1, id: vm.accounts.single.id), isTrue);
    expect(vm.accounts.single.details.lastFour, '0042');
    expect(vm.accounts.single.details.financialInstitutionId, 1);
    expect(vm.accounts.single.currentBalance.minorUnits, 29);
  });
}
