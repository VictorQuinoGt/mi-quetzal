import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/sqlite_account_repository.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String path;
  late LocalDatabase database;
  late SqliteAccountRepository repository;

  AccountDetails sample({
    String name = 'Cuenta sintética',
    Currency currency = Currency.gtq,
    AccountType type = AccountType.bank,
  }) => AccountDetails(
    name: name,
    type: type,
    openingBalance: Money(12345, currency),
    openingDate: DateTime(2026, 10, 1),
    creditLimit: type == AccountType.creditCard ? Money(50000, currency) : null,
    lastFour: type == AccountType.creditCard ? '0042' : null,
  );

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mi_quetzal_test_');
    path = p.join(directory.path, 'accounts.db');
    database = LocalDatabase(factory: databaseFactoryFfi, path: path);
    repository = SqliteAccountRepository(database);
  });
  tearDown(() async {
    await database.close();
    await databaseFactoryFfi.deleteDatabase(path);
    await directory.delete();
  });

  test(
    'Crea esquema versionado, activa claves foráneas y empieza vacío',
    () async {
      expect(await repository.getAccounts(), isEmpty);
      final db = await database.database;
      expect(await db.getVersion(), LocalDatabase.schemaVersion);
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
    },
  );

  test(
    'Persiste monedas y crédito después de cerrar y volver a abrir',
    () async {
      final bank = await repository.createAccount(sample());
      final credit = await repository.createAccount(
        sample(currency: Currency.usd, type: AccountType.creditCard),
      );
      await database.close();
      final accounts = await repository.getAccounts();
      expect(accounts.map((a) => a.id), [bank.id, credit.id]);
      expect(accounts.first.details.openingBalance, Money(12345, Currency.gtq));
      expect(accounts.last.details.openingBalance, Money(12345, Currency.usd));
      expect(accounts.last.details.creditLimit, Money(50000, Currency.usd));
      expect(accounts.last.details.lastFour, '0042');
      expect(accounts.last.details.openingDate, DateTime(2026, 10, 1));
    },
  );

  test(
    'Usa parámetros para alias y no elimina cuentas de nombre idéntico',
    () async {
      const alias = "Ahorro '); DROP TABLE accounts; --";
      final first = await repository.createAccount(sample(name: alias));
      final second = await repository.createAccount(sample(name: alias));
      expect(first.id, isNot(second.id));
      expect((await repository.getAccounts()).map((a) => a.details.name), [
        alias,
        alias,
      ]);
    },
  );

  test('Un fallo durante la escritura revierte todos sus efectos', () async {
    await repository.createAccount(sample());
    final db = await database.database;
    await db.execute('''CREATE TRIGGER reject_account AFTER INSERT ON accounts
      BEGIN SELECT RAISE(ABORT, 'Fallo sintético'); END''');
    await expectLater(
      repository.createAccount(sample()),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repository.getAccounts(), hasLength(1));
    await db.execute('DROP TRIGGER reject_account');
    await repository.createAccount(sample());
    expect(await repository.getAccounts(), hasLength(2));
  });

  test('El esquema rechaza datos que violan las reglas de cuenta', () async {
    final db = await database.database;
    final base = <String, Object?>{
      'name': 'Cuenta sintética',
      'type': 'bank',
      'currency': 'gtq',
      'opening_minor': 0,
      'opening_date': '2026-10-01',
    };
    for (final invalid in <Map<String, Object?>>[
      {'name': ' '},
      {'currency': 'eur'},
      {'type': 'debitCard'},
      {'type': 'cash', 'opening_minor': -1},
      {'type': 'creditCard', 'opening_minor': -1},
      {'credit_limit_minor': 100},
      {'type': 'creditCard', 'last_four': '12345'},
      {'type': 'creditCard', 'last_four': 'abcd'},
      {'type': 'creditCard', 'credit_limit_minor': -1},
    ]) {
      await expectLater(
        db.insert('accounts', {...base, ...invalid}),
        throwsA(isA<DatabaseException>()),
      );
    }
    expect(await repository.getAccounts(), isEmpty);
  });

  test('No borra una base creada por una versión más reciente', () async {
    await repository.createAccount(sample());
    final db = await database.database;
    await db.setVersion(LocalDatabase.schemaVersion + 1);
    await database.close();
    await expectLater(repository.getAccounts(), throwsStateError);
    final newer = await databaseFactoryFfi.openDatabase(path);
    expect(await newer.getVersion(), LocalDatabase.schemaVersion + 1);
    expect(await newer.query('accounts'), hasLength(1));
    await newer.close();
  });
}
