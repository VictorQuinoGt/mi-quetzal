import 'package:sqflite_common/sqlite_api.dart';

/// Reconstrucción transaccional de los esquemas 9/10, conservando ids y referencias.
/// Las bases existentes desactivan FK en onConfigure, antes de la transacción;
/// se comprueba su integridad antes de confirmar y se activan en onOpen.
Future<void> migratePaymentSupport(
  DatabaseExecutor db, {
  bool preservePaymentFunding = false,
}) async {
  final triggers = await db.rawQuery(
    "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND sql IS NOT NULL",
  );
  final indexes = await db.rawQuery(
    "SELECT sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL AND tbl_name IN ('categories','movements')",
  );
  final sequences = await db.rawQuery(
    "SELECT name, seq FROM sqlite_sequence WHERE name IN ('categories','movements')",
  );
  for (final trigger in triggers) {
    final name = (trigger['name'] as String).replaceAll('"', '""');
    await db.execute('DROP TRIGGER "$name"');
  }
  await db.execute('''CREATE TABLE categories_next (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60),
    kind TEXT NOT NULL CHECK(kind IN ('expense','income','payment')))
  ''');
  await db.execute(
    'INSERT INTO categories_next(id,name,kind) SELECT id,name,kind FROM categories',
  );
  await db.execute('''CREATE TABLE movements_next (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL CHECK(type IN ('expense','income','transfer','creditPayment','refund')),
    account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    counterparty_account_id INTEGER REFERENCES accounts(id) ON DELETE RESTRICT,
    amount_minor INTEGER NOT NULL CHECK(amount_minor BETWEEN 1 AND 9007199254740991),
    currency TEXT NOT NULL CHECK(currency IN ('gtq','usd')),
    occurred_on TEXT NOT NULL,
    description TEXT NOT NULL CHECK(length(trim(description)) BETWEEN 1 AND 120),
    debit_card_id INTEGER REFERENCES debit_cards(id) ON DELETE RESTRICT,
    category_id INTEGER REFERENCES categories(id) ON DELETE RESTRICT,
    original_movement_id INTEGER REFERENCES movements(id) ON DELETE RESTRICT,
    installment_plan_id INTEGER REFERENCES installment_plans(id) ON DELETE RESTRICT,
    installment_number INTEGER,
    origin TEXT NOT NULL DEFAULT 'manual' CHECK(origin IN ('manual','installmentCharge','installmentConversion')),
    recognized_expense_minor INTEGER CHECK(recognized_expense_minor IS NULL OR recognized_expense_minor BETWEEN 0 AND amount_minor),
    payment_funding TEXT NOT NULL DEFAULT 'account' CHECK(payment_funding IN ('account','externalCash')),
    CHECK((type IN ('expense','income','refund') AND counterparty_account_id IS NULL AND payment_funding = 'account') OR
      (type IN ('transfer','creditPayment') AND payment_funding = 'account' AND counterparty_account_id IS NOT NULL AND account_id <> counterparty_account_id) OR
      (type = 'creditPayment' AND payment_funding = 'externalCash' AND counterparty_account_id IS NULL AND debit_card_id IS NULL)),
    CHECK((type = 'refund' AND original_movement_id IS NOT NULL AND original_movement_id <> id AND category_id IS NULL AND debit_card_id IS NULL) OR
      (type <> 'refund' AND original_movement_id IS NULL)))
  ''');
  // Referenciar el nombre definitivo evita depender de que ALTER TABLE cambie
  // las FK con foreign_keys=OFF (SQLite antiguo o legacy_alter_table=ON).
  final columns =
      'id,type,account_id,counterparty_account_id,amount_minor,currency,occurred_on,description,debit_card_id,category_id,original_movement_id,installment_plan_id,installment_number,origin,recognized_expense_minor${preservePaymentFunding ? ',payment_funding' : ''}';
  await db.execute(
    'INSERT INTO movements_next($columns) SELECT $columns FROM movements',
  );
  await db.execute('DROP TABLE movements');
  await db.execute('DROP TABLE categories');
  await db.execute('ALTER TABLE categories_next RENAME TO categories');
  await db.execute('ALTER TABLE movements_next RENAME TO movements');
  for (final sequence in sequences) {
    final count = await db.rawUpdate(
      'UPDATE sqlite_sequence SET seq = MAX(seq, ?) WHERE name = ?',
      [sequence['seq'], sequence['name']],
    );
    if (count == 0) await db.insert('sqlite_sequence', sequence);
  }
  for (final index in indexes) {
    await db.execute(index['sql'] as String);
  }
  for (final trigger in triggers) {
    if (!{
      'movements_category_insert',
      'movements_category_update',
      'movements_payment_insert',
      'movements_payment_update',
      'categories_kind',
    }.contains(trigger['name'])) {
      await db.execute(trigger['sql'] as String);
    }
  }
  for (final event in ['INSERT', 'UPDATE']) {
    await db.execute(
      '''CREATE TRIGGER movements_category_${event.toLowerCase()} BEFORE $event ON movements
      WHEN NEW.category_id IS NOT NULL AND (NEW.type NOT IN ('expense','income','creditPayment') OR NOT EXISTS (
        SELECT 1 FROM categories WHERE id = NEW.category_id AND kind = CASE NEW.type WHEN 'creditPayment' THEN 'payment' ELSE NEW.type END))
      BEGIN SELECT RAISE(ABORT, 'Categoría incompatible'); END''',
    );
    await db.execute(
      '''CREATE TRIGGER movements_payment_${event.toLowerCase()} BEFORE $event ON movements
      WHEN NEW.type = 'creditPayment' AND (
        (NEW.payment_funding = 'externalCash' AND NOT EXISTS (
          SELECT 1 FROM accounts WHERE id = NEW.account_id AND type = 'creditCard' AND
            (currency = NEW.currency OR secondary_opening_minor IS NOT NULL))) OR
        (NEW.payment_funding = 'account' AND (NOT EXISTS (
          SELECT 1 FROM accounts WHERE id = NEW.account_id AND type IN ('bank','cash') AND currency = NEW.currency) OR NOT EXISTS (
          SELECT 1 FROM accounts WHERE id = NEW.counterparty_account_id AND type = 'creditCard' AND
            (currency = NEW.currency OR secondary_opening_minor IS NOT NULL)))))
      BEGIN SELECT RAISE(ABORT, 'Origen o tarjeta de pago incompatible'); END''',
    );
  }
  await db.execute(
    '''CREATE TRIGGER categories_kind BEFORE UPDATE OF kind ON categories
    WHEN EXISTS (SELECT 1 FROM movements WHERE category_id = NEW.id AND
      CASE type WHEN 'creditPayment' THEN 'payment' ELSE type END <> NEW.kind)
    BEGIN SELECT RAISE(ABORT, 'La categoría está en uso por otra operación'); END''',
  );
  final references = await db.rawQuery('PRAGMA foreign_key_list(movements)');
  final originalReference = references.where(
    (row) => row['from'] == 'original_movement_id',
  );
  // foreign_key_check no descubre el padre inexistente si todos los vínculos
  // son nulos. Comprobar también la estructura antes de confirmar la migración.
  if (originalReference.length != 1 ||
      originalReference.single['table'] != 'movements' ||
      (await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
    throw StateError(
      'La migración de pagos encontró referencias incompatibles.',
    );
  }
}
