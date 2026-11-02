import '../../domain/models/account.dart';

abstract interface class AccountRepository {
  Future<List<Account>> getAccounts();
  Future<Account> createAccount(AccountDetails details);
}
