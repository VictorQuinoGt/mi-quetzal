import '../../domain/models/account.dart';
import '../../domain/models/debit_card.dart';
import '../services/ledger_reader.dart';
import '../services/local_database.dart';
import 'account_repository.dart';

class SqliteAccountRepository implements AccountRepository {
  SqliteAccountRepository(this._database);
  final LocalDatabase _database;

  @override
  Future<List<DebitCard>> getDebitCards() async {
    final db = await _database.database;
    return db.transaction(
      (transaction) async => (await readLedger(transaction)).debitCards,
    );
  }

  @override
  Future<DebitCard> createDebitCard(DebitCardDetails details) async {
    final db = await _database.database;
    return db.transaction((transaction) async {
      details.validateAccount((await readLedger(transaction)).accounts);
      final id = await transaction.insert('debit_cards', {
        'name': details.name,
        'account_id': details.accountId,
        'last_four': details.lastFour,
      });
      return DebitCard(id: id, details: details);
    });
  }

  @override
  Future<List<Account>> getAccounts() async {
    final db = await _database.database;
    return db.transaction(
      (transaction) async => (await readLedger(transaction)).accounts,
    );
  }

  @override
  Future<Account> createAccount(AccountDetails details) async {
    final db = await _database.database;
    return db.transaction((transaction) async {
      final id = await transaction.insert('accounts', {
        'name': details.name,
        'type': details.type.name,
        'currency': details.openingBalance.currency.name,
        'opening_minor': details.openingBalance.minorUnits,
        'opening_date': details.openingDate.toIso8601String().substring(0, 10),
        'credit_limit_minor': details.creditLimit?.minorUnits,
        'last_four': details.lastFour,
      });
      return Account(id: id, details: details);
    });
  }
}
