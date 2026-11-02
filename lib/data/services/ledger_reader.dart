import 'package:sqflite_common/sqlite_api.dart';

import '../../domain/models/account.dart';
import '../../domain/models/category.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';

Future<LedgerSnapshot> readLedger(DatabaseExecutor db) async {
  final accountRows = await db.query('accounts', orderBy: 'id ASC');
  final cardRows = await db.query('debit_cards', orderBy: 'id ASC');
  final categoryRows = await db.query('categories', orderBy: 'id ASC');
  final movementRows = await db.query('movements', orderBy: 'id ASC');
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
        lastFour: row['last_four'] as String?,
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
  );
}
