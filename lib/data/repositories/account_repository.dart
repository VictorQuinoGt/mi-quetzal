import '../../domain/models/account.dart';
import '../../domain/models/debit_card.dart';

abstract interface class AccountRepository {
  Future<List<Account>> getAccounts();
  Future<Account> createAccount(AccountDetails details);
  Future<Account> updateAccount(int id, AccountDetails details);
  Future<List<DebitCard>> getDebitCards();
  Future<DebitCard> createDebitCard(DebitCardDetails details);
  Future<DebitCard> updateDebitCard(int id, DebitCardDetails details);
}
