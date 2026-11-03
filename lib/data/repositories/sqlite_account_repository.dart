import '../../domain/models/account.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/movement.dart';
import '../../domain/models/financial_institution.dart';
import '../../domain/rules/account_rules.dart';
import '../services/ledger_reader.dart';
import '../services/local_database.dart';
import 'account_repository.dart';

class SqliteAccountRepository implements AccountRepository {
  SqliteAccountRepository(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final LocalDatabase _database;
  final DateTime Function() _now;
  @override
  Future<List<FinancialInstitution>> getFinancialInstitutions() async {
    final db = await _database.database;
    return db.transaction(
      (tx) async => (await readLedger(tx)).financialInstitutions,
    );
  }

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
      final snapshot = await readLedger(transaction);
      details.validateAccount(snapshot.accounts);
      details.validateFinancialInstitution(snapshot.financialInstitutions);
      final id = await transaction.insert('debit_cards', {
        'name': details.name,
        'account_id': details.accountId,
        'last_four': details.lastFour,
        'financial_institution_id': details.financialInstitutionId,
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
      details.validateFinancialInstitution(
        (await readLedger(transaction)).financialInstitutions,
      );
      final id = await transaction.insert('accounts', _values(details));
      return Account(id: id, details: details);
    });
  }

  @override
  Future<Account> updateAccount(int id, AccountDetails details) async {
    final db = await _database.database;
    return db.transaction((transaction) async {
      final before = await readLedger(transaction);
      details.validateFinancialInstitution(before.financialInstitutions);
      final matches = before.accounts.where((a) => a.id == id);
      if (matches.isEmpty) {
        throw ArgumentError('La cuenta ya no existe.', 'name');
      }
      AccountRules.validateUpdate(
        matches.single,
        details,
        movements: before.movements,
      );
      final now = _now();
      if (details.openingDate.isAfter(DateTime(now.year, now.month, now.day))) {
        throw ArgumentError(
          'El saldo inicial no puede tener una fecha futura.',
          'openingDate',
        );
      }
      await transaction.update(
        'accounts',
        _values(details),
        where: 'id = ?',
        whereArgs: [id],
      );
      try {
        final after = await readLedger(transaction);
        return after.accounts.singleWhere((a) => a.id == id);
      } on MovementValidationException catch (error) {
        throw ArgumentError(
          'El cambio no es compatible con el historial. ${error.message}',
          error.field == 'date' ? 'openingDate' : 'openingBalance',
        );
      }
    });
  }

  @override
  Future<DebitCard> updateDebitCard(int id, DebitCardDetails details) async {
    final db = await _database.database;
    return db.transaction((transaction) async {
      final snapshot = await readLedger(transaction);
      if (!snapshot.debitCards.any((c) => c.id == id)) {
        throw const DebitCardValidationException(
          'name',
          'La tarjeta ya no existe.',
        );
      }
      details.validateAccount(snapshot.accounts);
      details.validateFinancialInstitution(snapshot.financialInstitutions);
      AccountRules.validateDebitUpdate(id, details, snapshot.movements);
      await transaction.update(
        'debit_cards',
        {
          'name': details.name,
          'account_id': details.accountId,
          'last_four': details.lastFour,
          'financial_institution_id': details.financialInstitutionId,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await readLedger(transaction);
      return DebitCard(id: id, details: details);
    });
  }

  Map<String, Object?> _values(AccountDetails details) => {
    'name': details.name,
    'type': details.type.name,
    'currency': details.openingBalance.currency.name,
    'opening_minor': details.openingBalance.minorUnits,
    'opening_date': details.openingDate.toIso8601String().substring(0, 10),
    'credit_limit_minor': details.creditLimit?.minorUnits,
    'last_four': details.type == AccountType.creditCard
        ? details.lastFour
        : null,
    'bank_last_four': details.type == AccountType.bank
        ? details.lastFour
        : null,
    'financial_institution_id': details.financialInstitutionId,
    'bank_account_type': details.bankAccountType?.name,
    'secondary_opening_minor': details.secondaryOpeningBalance?.minorUnits,
    'secondary_credit_limit_minor': details.secondaryCreditLimit?.minorUnits,
  };
}
