import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/services/local_database.dart';
import 'package:mi_quetzal/data/repositories/sqlite_movement_repository.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:sqflite_common/sqlite_api.dart';

/// Reproduce solo en datos sintéticos la FK temporal que dejó la v10 desplegada.
Future<void> leaveTemporaryMovementReference(Database db) async {
  await db.execute('PRAGMA foreign_keys = OFF');
  await db.execute('PRAGMA legacy_alter_table = ON');
  await db.transaction((tx) async {
    final sql =
        (await tx.rawQuery(
              "SELECT sql FROM sqlite_master WHERE name = 'movements'",
            )).single['sql']
            as String;
    final broken = sql
        .replaceFirst(
          RegExp(r'^CREATE TABLE\s+(?:"movements"|movements)\s*\('),
          'CREATE TABLE movements_fixture (',
        )
        .replaceFirst(
          RegExp(r'REFERENCES\s+(?:"movements"|movements)\s*\(id\)'),
          'REFERENCES movements_next(id)',
        );
    expect(broken, contains('REFERENCES movements_next(id)'));
    final triggers = await tx.rawQuery(
      "SELECT name,sql FROM sqlite_master WHERE type = 'trigger'",
    );
    final indexes = await tx.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'index' AND tbl_name = 'movements' AND sql IS NOT NULL",
    );
    final sequence =
        (await tx.rawQuery(
          "SELECT seq FROM sqlite_sequence WHERE name = 'movements'",
        )).firstOrNull?['seq'] ??
        0;
    for (final trigger in triggers) {
      final name = (trigger['name'] as String).replaceAll('"', '""');
      await tx.execute('DROP TRIGGER "$name"');
    }
    await tx.execute(broken);
    await tx.execute('INSERT INTO movements_fixture SELECT * FROM movements');
    await tx.execute('DROP TABLE movements');
    await tx.execute('ALTER TABLE movements_fixture RENAME TO movements');
    await tx.rawUpdate(
      "UPDATE sqlite_sequence SET seq = ? WHERE name = 'movements'",
      [sequence],
    );
    for (final row in [...indexes, ...triggers]) {
      await tx.execute(row['sql'] as String);
    }
  });
}

Future<void> verifyLegacyMovementUpgrade(
  DatabaseFactory factory,
  String path,
  int version,
) async {
  var db = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, version) => LocalDatabase.migrate(db, 0, version),
    ),
  );
  await db.insert('accounts', {
    'id': 1,
    'name': 'Tarjeta sintética',
    'type': 'creditCard',
    'currency': 'gtq',
    'opening_minor': 10000,
    'opening_date': '2026-11-01',
  });
  await db.insert('movements', {
    'type': 'expense',
    'account_id': 1,
    'amount_minor': 100,
    'currency': 'gtq',
    'occurred_on': '2026-11-01',
    'description': 'Compra anterior sintética',
  });
  await db.close();
  db = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 11,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = OFF');
        await db.execute('PRAGMA legacy_alter_table = ON');
      },
      onUpgrade: LocalDatabase.migrate,
      onOpen: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
  try {
    expect(
      (await db.rawQuery('PRAGMA foreign_key_list(movements)'))
          .singleWhere((r) => r['from'] == 'original_movement_id')['table'],
      'movements',
    );
    for (final type in ['expense', 'creditPayment']) {
      await db.insert('movements', {
        'type': type,
        'account_id': 1,
        'amount_minor': 100,
        'payment_funding': type == 'creditPayment' ? 'externalCash' : 'account',
        'currency': 'gtq',
        'occurred_on': '2026-11-01',
        'description': 'Movimiento nuevo sintético',
      });
    }
    expect(await db.query('movements'), hasLength(3));
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  } finally {
    await db.close();
  }
}

/// Se invoca después del escenario de pagos: incluye compras, devoluciones,
/// débito, categorías, cuotas, conciliaciones y pagos externos persistidos.
Future<void> verifyMovementReferenceRepair(
  DatabaseFactory factory,
  String path,
) async {
  for (final broken in [false, true]) {
    final previous = await factory.openDatabase(path);
    await previous.setVersion(10);
    if (broken) await leaveTemporaryMovementReference(previous);
    const tables = [
      'accounts',
      'debit_cards',
      'categories',
      'movements',
      'installment_plans',
      'installments',
      'installment_reconciliations',
      'installment_revisions',
      'sqlite_sequence',
    ];
    final before = {
      for (final table in tables) table: await previous.query(table),
    };
    final schemaBefore = await previous.rawQuery(
      'SELECT name,sql FROM sqlite_master ORDER BY name',
    );
    if (broken) {
      await previous.execute('PRAGMA foreign_keys = ON');
      await expectLater(
        previous.insert('movements', {
          'type': 'expense',
          'account_id': 1,
          'amount_minor': 100,
          'currency': 'gtq',
          'occurred_on': '2026-11-01',
          'description': 'Compra sintética',
        }),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.isNoSuchTableError(),
            'tabla temporal inexistente',
            isTrue,
          ),
        ),
      );
    }
    await previous.close();
    await expectLater(
      factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 11,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = OFF');
            await db.execute('PRAGMA legacy_alter_table = ON');
          },
          onUpgrade: (db, from, to) async {
            await LocalDatabase.migrate(db, from, to);
            throw StateError('Fallo sintético al reparar v10');
          },
        ),
      ),
      throwsA(anything),
    );
    final rollback = await factory.openDatabase(path);
    expect(await rollback.getVersion(), 10);
    expect(
      await rollback.rawQuery(
        'SELECT name,sql FROM sqlite_master ORDER BY name',
      ),
      schemaBefore,
    );
    for (final table in tables) {
      expect(await rollback.query(table), before[table], reason: table);
    }
    await rollback.close();
    final local = LocalDatabase(factory: factory, path: path);
    try {
      final db = await local.database;
      expect(await db.getVersion(), 11);
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await db.rawQuery('PRAGMA foreign_key_list(movements)'))
            .singleWhere((r) => r['from'] == 'original_movement_id')['table'],
        'movements',
      );
      for (final table in tables) {
        expect(await db.query(table), before[table], reason: table);
      }
      final repo = SqliteMovementRepository(
        local,
        now: () => DateTime(2026, 11, 1),
      );
      final snapshot = await repo.getSnapshot();
      final debt = snapshot.accounts.first.balanceFor(Currency.usd)!.minorUnits;
      for (final type in [MovementType.expense, MovementType.creditPayment]) {
        final saved = await repo.createMovement(
          MovementDetails(
            type: type,
            accountId: 1,
            paymentFunding: type == MovementType.creditPayment
                ? PaymentFunding.externalCash
                : PaymentFunding.account,
            categoryId: type == MovementType.creditPayment
                ? snapshot.categories
                      .singleWhere((c) => c.details.kind.name == 'payment')
                      .id
                : 1,
            amount: Money(100, Currency.usd),
            date: DateTime(2026, 11, 1),
            description: 'Movimiento posterior sintético',
          ),
        );
        expect(
          saved.accounts.first.balanceFor(Currency.usd)!.minorUnits,
          type == MovementType.expense ? debt + 100 : debt,
        );
      }
      await local.close();
      final reopened = LocalDatabase(factory: factory, path: path);
      try {
        final saved = await SqliteMovementRepository(
          reopened,
          now: () => DateTime(2026, 11, 1),
        ).getSnapshot();
        expect(saved.movements.length, before['movements']!.length + 2);
        expect(saved.accounts.first.balanceFor(Currency.usd)!.minorUnits, debt);
      } finally {
        await reopened.close();
      }
    } finally {
      await local.close();
    }
  }
}
