import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

class LocalDatabase {
  LocalDatabase({required this.factory, this.path});

  static const schemaVersion = 2;
  final DatabaseFactory factory;
  final String? path;
  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final location =
          path ?? p.join(await factory.getDatabasesPath(), 'mi_quetzal.db');
      return await factory.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) => migrate(db, 0, version),
          onUpgrade: migrate,
          onDowngrade: (db, oldVersion, newVersion) async {
            throw StateError(
              'La base requiere una versión más reciente de Mi Quetzal.',
            );
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  /// sqflite ejecuta estos callbacks dentro de una transacción.
  static Future<void> migrate(Database db, int from, int to) async {
    if (from < 1 && to >= 1) {
      await db.execute('''
        CREATE TABLE accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60),
          type TEXT NOT NULL CHECK(type IN ('cash', 'bank', 'creditCard')),
          currency TEXT NOT NULL CHECK(currency IN ('gtq', 'usd')),
          opening_minor INTEGER NOT NULL CHECK(abs(opening_minor) <= 9007199254740991),
          opening_date TEXT NOT NULL,
          credit_limit_minor INTEGER,
          last_four TEXT,
          CHECK(type = 'bank' OR opening_minor >= 0),
          CHECK(credit_limit_minor IS NULL OR
            (type = 'creditCard' AND credit_limit_minor BETWEEN 0 AND 9007199254740991)),
          CHECK(last_four IS NULL OR
            (type = 'creditCard' AND length(last_four) = 4 AND last_four NOT GLOB '*[^0-9]*'))
        )
      ''');
    }
    if (from < 2 && to >= 2) {
      await db.execute('''
        CREATE TABLE movements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL CHECK(type IN ('expense', 'income', 'transfer', 'creditPayment')),
          account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
          counterparty_account_id INTEGER REFERENCES accounts(id) ON DELETE RESTRICT,
          amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 1 AND 9007199254740991),
          currency TEXT NOT NULL CHECK(currency IN ('gtq', 'usd')),
          occurred_on TEXT NOT NULL,
          description TEXT NOT NULL CHECK(length(trim(description)) BETWEEN 1 AND 120),
          CHECK((type IN ('expense', 'income') AND counterparty_account_id IS NULL) OR
            (type IN ('transfer', 'creditPayment') AND counterparty_account_id IS NOT NULL AND
              account_id <> counterparty_account_id))
        )
      ''');
      await db.execute(
        'CREATE INDEX movements_by_date ON movements(occurred_on, id)',
      );
    }
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    _opening = null;
  }
}
