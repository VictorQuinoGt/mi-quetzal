import 'package:sqflite_common/sqlite_api.dart';

import '../../domain/models/account.dart';
import '../../domain/models/category.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/financial_institution.dart';
import 'installment_codec.dart';

Future<LedgerSnapshot> readLedger(DatabaseExecutor db) async {
  final plans = await readPlans(db);
  final reconciliations = await db.query('installment_reconciliations');
  final accountRows = await db.query('accounts', orderBy: 'id ASC');
  final cardRows = await db.query('debit_cards', orderBy: 'id ASC');
  final categoryRows = await db.query('categories', orderBy: 'id ASC');
  final movementRows = await db.query('movements', orderBy: 'id ASC');
  final institutionRows = await db.query(
    'financial_institutions',
    orderBy: 'id ASC',
  );
  final accounts = accountRows.map((row) {
    final currency = Currency.values.byName(row['currency'] as String);
    final limit = row['credit_limit_minor'] as int?;
    final other = currency == Currency.gtq ? Currency.usd : Currency.gtq;
    final secondaryOpening = row['secondary_opening_minor'] as int?;
    final secondaryLimit = row['secondary_credit_limit_minor'] as int?;
    return Account(
      id: row['id'] as int,
      details: AccountDetails(
        name: row['name'] as String,
        type: AccountType.values.byName(row['type'] as String),
        openingBalance: Money(row['opening_minor'] as int, currency),
        openingDate: DateTime.parse(row['opening_date'] as String),
        creditLimit: limit == null ? null : Money(limit, currency),
        lastFour:
            (row['type'] == 'bank' ? row['bank_last_four'] : row['last_four'])
                as String?,
        financialInstitutionId: row['financial_institution_id'] as int?,
        nextClosingDate: row['next_closing_date'] == null
            ? null
            : DateTime.parse(row['next_closing_date'] as String),
        nextPaymentDueDate: row['next_payment_due_date'] == null
            ? null
            : DateTime.parse(row['next_payment_due_date'] as String),
        bankAccountType: row['bank_account_type'] == null
            ? null
            : BankAccountType.values.byName(row['bank_account_type'] as String),
        secondaryOpeningBalance: secondaryOpening == null
            ? null
            : Money(secondaryOpening, other),
        secondaryCreditLimit: secondaryLimit == null
            ? null
            : Money(secondaryLimit, other),
      ),
    );
  }).toList();
  final movements = movementRows
      .map(
        (row) => Movement(
          id: row['id'] as int,
          details: MovementDetails(
            type: MovementType.values.byName(row['type'] as String),
            accountId: row['account_id'] as int,
            counterpartyAccountId: row['counterparty_account_id'] as int?,
            debitCardId: row['debit_card_id'] as int?,
            categoryId: row['category_id'] as int?,
            originalMovementId: row['original_movement_id'] as int?,
            origin: MovementOrigin.values.byName(row['origin'] as String),
            installmentPlanId: row['installment_plan_id'] as int?,
            installmentNumber: row['installment_number'] as int?,
            recognizedExpenseMinor: row['recognized_expense_minor'] as int?,
            reconciledIntoId: reconciliations
                .where((r) => r['source_movement_id'] == row['id'])
                .map((r) => r['target_movement_id'] as int)
                .firstOrNull,
            reconciled: reconciliations.any(
              (r) => r['target_movement_id'] == row['id'],
            ),
            amount: Money(
              row['amount_minor'] as int,
              Currency.values.byName(row['currency'] as String),
            ),
            date: DateTime.parse(row['occurred_on'] as String),
            description: row['description'] as String,
          ),
        ),
      )
      .toList();
  final debitCards = cardRows
      .map(
        (row) => DebitCard(
          id: row['id'] as int,
          details: DebitCardDetails(
            name: row['name'] as String,
            accountId: row['account_id'] as int,
            lastFour: row['last_four'] as String?,
            financialInstitutionId: row['financial_institution_id'] as int?,
          ),
        ),
      )
      .toList();
  final categories = categoryRows
      .map(
        (row) => Category(
          id: row['id'] as int,
          details: CategoryDetails(
            name: row['name'] as String,
            kind: CategoryKind.values.byName(row['kind'] as String),
          ),
        ),
      )
      .toList();
  return LedgerSnapshot.calculate(
    accounts,
    movements,
    debitCards: debitCards,
    categories: categories,
    installmentPlans: plans,
    financialInstitutions: [
      for (final row in institutionRows)
        FinancialInstitution(
          id: row['id'] as int,
          details: FinancialInstitutionDetails(name: row['name'] as String),
        ),
    ],
  );
}
