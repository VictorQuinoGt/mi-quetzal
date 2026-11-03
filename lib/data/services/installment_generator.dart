import 'package:sqflite_common/sqlite_api.dart';

import 'installment_codec.dart';

/// Se llama dentro de la misma transacción que lee o modifica el ledger.
Future<void> generateDueInstallments(DatabaseExecutor db, DateTime now) async {
  final today = DateTime(now.year, now.month, now.day);
  final plans = await readPlans(db);
  for (final plan in plans) {
    for (final row in plan.pending.where((i) => !i.date.isAfter(today))) {
      final expense = plan.draft.originalMovementId == null
          ? row.amount.minorUnits
          : (row.interest?.minorUnits ?? 0) + (row.fee?.minorUnits ?? 0);
      final id = await db.insert('movements', {
        'type': 'expense',
        'account_id': plan.draft.accountId,
        'category_id': plan.draft.categoryId,
        'amount_minor': row.amount.minorUnits,
        'currency': row.amount.currency.name,
        'occurred_on': isoDay(row.date),
        'description':
            '${plan.draft.description} · Cuota ${row.number}/${plan.schedule.length}',
        'origin': 'installmentCharge',
        'installment_plan_id': plan.id,
        'installment_number': row.number,
        'recognized_expense_minor': expense,
      });
      await db.update(
        'installments',
        {'movement_id': id},
        where: 'plan_id = ? AND number = ? AND movement_id IS NULL',
        whereArgs: [plan.id, row.number],
      );
    }
  }
}
