import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debit_card.dart';
import 'package:mi_quetzal/domain/models/financial_institution.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';

void main() {
  test(
    'Entidad normaliza nombre, conserva identidad y rechaza vacío o exceso',
    () {
      expect(
        FinancialInstitutionDetails(name: '  Entidad sintética  ').name,
        'Entidad sintética',
      );
      for (final name in ['', '   ', 'a' * 61]) {
        expect(
          () => FinancialInstitutionDetails(name: name),
          throwsA(isA<FinancialInstitutionValidationException>()),
        );
      }
    },
  );
  test('Banco admite terminación y entidad sin afectar saldo ni duplicar fondos con débito', () {
    final institution = FinancialInstitution(
      id: 1,
      details: FinancialInstitutionDetails(name: 'Entidad sintética'),
    );
    final bank = Account(
      id: 1,
      details: AccountDetails(
        name: 'Banco sintético',
        type: AccountType.bank,
        financialInstitutionId: 1,
        lastFour: '0042',
        openingBalance: Money(29, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
    );
    final debit = DebitCard(
      id: 1,
      details: DebitCardDetails(
        name: 'Débito sintético',
        accountId: 1,
        financialInstitutionId: 1,
      ),
    );
    final ledger = LedgerSnapshot.calculate(
      [bank],
      [],
      debitCards: [debit],
      financialInstitutions: [institution],
    );
    expect(ledger.accounts.single.currentBalance.minorUnits, 29);
    expect(ledger.accounts.single.details.lastFour, '0042');
    expect(ledger.financialInstitutions.single.id, 1);
    expect(() => ledger.financialInstitutions.clear(), throwsUnsupportedError);
    expect(() => LedgerSnapshot.calculate([bank], []), throwsArgumentError);
    expect(
      () => debit.details.validateFinancialInstitution([]),
      throwsA(isA<DebitCardValidationException>()),
    );
  });
  test('Efectivo no admite entidad ni terminación; bancos rechazan números completos o no numéricos', () {
    for (final digits in ['123', '12345', 'abcd']) {
      expect(
        () => AccountDetails(
          name: 'Banco sintético',
          type: AccountType.bank,
          lastFour: digits,
          openingBalance: Money(0, Currency.gtq),
          openingDate: DateTime(2026, 10, 1),
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => AccountDetails(
        name: 'Efectivo sintético',
        type: AccountType.cash,
        financialInstitutionId: 1,
        openingBalance: Money(0, Currency.gtq),
        openingDate: DateTime(2026, 10, 1),
      ),
      throwsArgumentError,
    );
  });
}
