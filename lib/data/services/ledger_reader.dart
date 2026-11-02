import 'package:sqflite_common/sqlite_api.dart';

import '../../domain/models/account.dart';
import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';

Future<LedgerSnapshot> readLedger(DatabaseExecutor db) async {
  final accountRows = await db.query('accounts', orderBy: 'id ASC');
  final movementRows = await db.query('movements', orderBy: 'id ASC');
  final accounts = accountRows.map((row) {
    final currency = Currency.values.byName(row['currency'] as String);
    final limit = row['credit_limit_minor'] as int?;
    return Account(
      id: row['id'] as int,
      details: AccountDetails(
        name: row['name'] as String,
        type: AccountType.values.byName(row['type'] as String),
        openingBalance: Money(row['opening_minor'] as int, currency),
        openingDate: DateTime.parse(row['opening_date'] as String),
        creditLimit: limit == null ? null : Money(limit, currency),
        lastFour: row['last_four'] as String?,
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
  return LedgerSnapshot.calculate(accounts, movements);
}
