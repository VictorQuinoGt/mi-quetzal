import 'package:sqflite_common/sqlite_api.dart';

import '../../domain/models/installment_plan.dart';
import '../../domain/models/money.dart';

String isoDay(DateTime date) => date.toIso8601String().substring(0, 10);
Map<String, Object?> draftValues(InstallmentDraft d) => {
  'description': d.description,
  'original_description': d.description,
  'account_id': d.accountId,
  'category_id': d.categoryId,
  'currency': d.originalAmount.currency.name,
  'original_minor': d.originalAmount.minorUnits,
  'count': d.count,
  'monthly_minor': d.monthlyAmount.minorUnits,
  'first_date': isoDay(d.firstDate),
  'charge_day': d.chargeDay,
  'previous_count': d.previousCount,
  'reference_date': isoDay(d.referenceDate),
  'cost_mode': d.costMode.name,
  'limit_mode': d.limitMode.name,
  'monthly_principal': d.monthlyPrincipal?.minorUnits,
  'monthly_interest': d.monthlyInterest?.minorUnits,
  'monthly_fee': d.monthlyFee?.minorUnits,
  'original_movement_id': d.originalMovementId,
};
Map<String, Object?> installmentValues(int plan, Installment i) => {
  'plan_id': plan,
  'number': i.number,
  'due_date': isoDay(i.date),
  'amount_minor': i.amount.minorUnits,
  'principal_minor': i.principal?.minorUnits,
  'interest_minor': i.interest?.minorUnits,
  'fee_minor': i.fee?.minorUnits,
  'previously_loaded': i.previouslyLoaded ? 1 : 0,
  'movement_id': i.movementId,
};
Future<List<InstallmentPlan>> readPlans(DatabaseExecutor db) async {
  final headers = await db.query('installment_plans', orderBy: 'id');
  final rows = await db.query('installments', orderBy: 'number');
  return [
    for (final h in headers)
      (() {
        final currency = Currency.values.byName(h['currency'] as String);
        Money? money(String field) =>
            h[field] == null ? null : Money(h[field] as int, currency);
        final draft = InstallmentDraft(
          description: h['description'] as String,
          accountId: h['account_id'] as int,
          categoryId: h['category_id'] as int?,
          originalAmount: money('original_minor')!,
          count: h['count'] as int,
          monthlyAmount: money('monthly_minor')!,
          firstDate: DateTime.parse(h['first_date'] as String),
          chargeDay: h['charge_day'] as int,
          previousCount: h['previous_count'] as int,
          referenceDate: DateTime.parse(h['reference_date'] as String),
          costMode: InstallmentCostMode.values.byName(h['cost_mode'] as String),
          limitMode: InstallmentLimitMode.values.byName(
            h['limit_mode'] as String,
          ),
          monthlyPrincipal: money('monthly_principal'),
          monthlyInterest: money('monthly_interest'),
          monthlyFee: money('monthly_fee'),
          originalMovementId: h['original_movement_id'] as int?,
        );
        return InstallmentPlan(
          id: h['id'] as int,
          draft: draft,
          originalDescription: h['original_description'] as String,
          cancelled: h['cancelled'] == 1,
          schedule: List.unmodifiable([
            for (final row in rows.where((r) => r['plan_id'] == h['id']))
              Installment(
                number: row['number'] as int,
                date: DateTime.parse(row['due_date'] as String),
                amount: Money(row['amount_minor'] as int, currency),
                principal: row['principal_minor'] == null
                    ? null
                    : Money(row['principal_minor'] as int, currency),
                interest: row['interest_minor'] == null
                    ? null
                    : Money(row['interest_minor'] as int, currency),
                fee: row['fee_minor'] == null
                    ? null
                    : Money(row['fee_minor'] as int, currency),
                movementId: row['movement_id'] as int?,
                previouslyLoaded: row['previously_loaded'] == 1,
              ),
          ]),
        );
      })(),
  ];
}
