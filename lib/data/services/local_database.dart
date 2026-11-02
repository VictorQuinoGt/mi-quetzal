import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';

class LocalDatabase {
  LocalDatabase({required this.factory, this.path});

  static const schemaVersion = 6;
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
    if (from < 3 && to >= 3) {
      await db.execute('''
        CREATE TABLE debit_cards (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60),
          account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
          last_four TEXT CHECK(last_four IS NULL OR
            (length(last_four) = 4 AND last_four NOT GLOB '*[^0-9]*'))
        )
      ''');
      await db.execute(
        'ALTER TABLE movements ADD COLUMN debit_card_id INTEGER REFERENCES debit_cards(id) ON DELETE RESTRICT',
      );
      await db.execute(
        'CREATE INDEX debit_cards_by_account ON debit_cards(account_id)',
      );
      for (final event in ['INSERT', 'UPDATE']) {
        await db.execute('''
          CREATE TRIGGER debit_cards_bank_${event.toLowerCase()} BEFORE $event ON debit_cards
          WHEN NOT EXISTS (SELECT 1 FROM accounts WHERE id = NEW.account_id AND type = 'bank')
            OR EXISTS (SELECT 1 FROM movements WHERE debit_card_id = NEW.id AND account_id <> NEW.account_id)
          BEGIN SELECT RAISE(ABORT, 'Vinculación bancaria incompatible'); END
        ''');
        await db.execute('''
          CREATE TRIGGER movements_debit_${event.toLowerCase()} BEFORE $event ON movements
          WHEN NEW.debit_card_id IS NOT NULL AND (NEW.type <> 'expense' OR NOT EXISTS
            (SELECT 1 FROM debit_cards WHERE id = NEW.debit_card_id AND account_id = NEW.account_id))
          BEGIN SELECT RAISE(ABORT, 'Tarjeta de débito incompatible'); END
        ''');
      }
      await db.execute('''
        CREATE TRIGGER accounts_with_debit BEFORE UPDATE OF type ON accounts
        WHEN NEW.type <> 'bank' AND EXISTS (SELECT 1 FROM debit_cards WHERE account_id = NEW.id)
        BEGIN SELECT RAISE(ABORT, 'La cuenta tiene tarjetas de débito vinculadas'); END
      ''');
    }
    if (from < 4 && to >= 4) {
      await db.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60),
          kind TEXT NOT NULL CHECK(kind IN ('expense', 'income'))
        )
      ''');
      await db.execute(
        'ALTER TABLE movements ADD COLUMN category_id INTEGER REFERENCES categories(id) ON DELETE RESTRICT',
      );
      for (final event in ['INSERT', 'UPDATE']) {
        await db.execute('''
          CREATE TRIGGER movements_category_${event.toLowerCase()} BEFORE $event ON movements
          WHEN NEW.category_id IS NOT NULL AND NOT EXISTS
            (SELECT 1 FROM categories WHERE id = NEW.category_id AND kind = NEW.type)
          BEGIN SELECT RAISE(ABORT, 'Categoría incompatible'); END
        ''');
      }
      await db.execute('''
        CREATE TRIGGER categories_kind BEFORE UPDATE OF kind ON categories
        WHEN EXISTS (SELECT 1 FROM movements WHERE category_id = NEW.id AND type <> NEW.kind)
        BEGIN SELECT RAISE(ABORT, 'La categoría está en uso por otra operación'); END
      ''');
    }
    if (from < 5 && to >= 5) await _addRefunds(db);
    if (from < 6 && to >= 6) {
      await db.execute(
        "ALTER TABLE accounts ADD COLUMN bank_account_type TEXT CHECK(bank_account_type IS NULL OR (type = 'bank' AND bank_account_type IN ('monetary', 'savings')))",
      );
      await db.execute(
        "ALTER TABLE accounts ADD COLUMN secondary_opening_minor INTEGER CHECK(secondary_opening_minor IS NULL OR (type = 'creditCard' AND secondary_opening_minor BETWEEN 0 AND 9007199254740991))",
      );
      await db.execute(
        "ALTER TABLE accounts ADD COLUMN secondary_credit_limit_minor INTEGER CHECK(secondary_credit_limit_minor IS NULL OR (secondary_opening_minor IS NOT NULL AND secondary_credit_limit_minor BETWEEN 0 AND 9007199254740991))",
      );
    }
  }

  static Future<void> _addRefunds(Database db) async {
    // SQLite no permite ampliar un CHECK con ALTER COLUMN. Reconstruimos solo
    // movimientos dentro de la transacción de migración, conservando sus ids.
    final triggers = await db.rawQuery('''
      SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND name IN (
        'debit_cards_bank_insert', 'debit_cards_bank_update',
        'movements_debit_insert', 'movements_debit_update',
        'movements_category_insert', 'movements_category_update', 'categories_kind')
    ''');
    final sequence = await db.rawQuery(
      'SELECT seq FROM sqlite_sequence WHERE name = ?',
      ['movements'],
    );
    for (final trigger in triggers) {
      await db.execute('DROP TRIGGER "${trigger['name']}"');
    }
    await db.execute('''
      CREATE TABLE movements_with_refunds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL CHECK(type IN ('expense', 'income', 'transfer', 'creditPayment', 'refund')),
        account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        counterparty_account_id INTEGER REFERENCES accounts(id) ON DELETE RESTRICT,
        amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 1 AND 9007199254740991),
        currency TEXT NOT NULL CHECK(currency IN ('gtq', 'usd')),
        occurred_on TEXT NOT NULL,
        description TEXT NOT NULL CHECK(length(trim(description)) BETWEEN 1 AND 120),
        debit_card_id INTEGER REFERENCES debit_cards(id) ON DELETE RESTRICT,
        category_id INTEGER REFERENCES categories(id) ON DELETE RESTRICT,
        original_movement_id INTEGER REFERENCES movements_with_refunds(id) ON DELETE RESTRICT,
        CHECK((type IN ('expense', 'income', 'refund') AND counterparty_account_id IS NULL) OR
          (type IN ('transfer', 'creditPayment') AND counterparty_account_id IS NOT NULL AND account_id <> counterparty_account_id)),
        CHECK((type = 'refund' AND original_movement_id IS NOT NULL AND original_movement_id <> id
          AND category_id IS NULL AND debit_card_id IS NULL) OR
          (type <> 'refund' AND original_movement_id IS NULL))
      )
    ''');
    await db.execute('''
      INSERT INTO movements_with_refunds
        (id, type, account_id, counterparty_account_id, amount_minor, currency,
         occurred_on, description, debit_card_id, category_id)
      SELECT id, type, account_id, counterparty_account_id, amount_minor, currency,
         occurred_on, description, debit_card_id, category_id FROM movements
    ''');
    await db.execute('DROP TABLE movements');
    await db.execute('ALTER TABLE movements_with_refunds RENAME TO movements');
    if (sequence.isNotEmpty) {
      // No reutilizar tampoco ids de filas eliminadas antes de la migración.
      await db.rawUpdate('UPDATE sqlite_sequence SET seq = ? WHERE name = ?', [
        sequence.single['seq'],
        'movements',
      ]);
    }
    await db.execute(
      'CREATE INDEX movements_by_date ON movements(occurred_on, id)',
    );
    await db.execute(
      'CREATE INDEX movements_by_original ON movements(original_movement_id)',
    );
    for (final trigger in triggers) {
      await db.execute(trigger['sql'] as String);
    }
    for (final event in ['INSERT', 'UPDATE']) {
      await db.execute('''
        CREATE TRIGGER movements_refund_${event.toLowerCase()} BEFORE $event ON movements
        WHEN NEW.type = 'refund' AND NOT EXISTS (
          SELECT 1 FROM movements AS original WHERE original.id = NEW.original_movement_id
            AND original.type = 'expense' AND original.account_id = NEW.account_id
            AND original.currency = NEW.currency AND original.occurred_on <= NEW.occurred_on
            AND NEW.amount_minor <= original.amount_minor - COALESCE((
              SELECT SUM(amount_minor) FROM movements WHERE original_movement_id = original.id
                AND id <> NEW.id), 0))
        BEGIN SELECT RAISE(ABORT, 'Devolución incompatible con la compra'); END
      ''');
    }
    await db.execute('''
      CREATE TRIGGER movements_refunded_original BEFORE UPDATE OF
        type, account_id, amount_minor, currency, occurred_on ON movements
      WHEN EXISTS (SELECT 1 FROM movements WHERE original_movement_id = OLD.id)
      BEGIN SELECT RAISE(ABORT, 'La compra tiene devoluciones vinculadas'); END
    ''');
    if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw StateError('La migración encontró referencias incompatibles.');
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
