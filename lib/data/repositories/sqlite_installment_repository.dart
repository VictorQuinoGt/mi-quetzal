import '../../domain/models/account.dart';
import '../../domain/models/category.dart';
import '../../domain/models/installment_plan.dart';
import '../../domain/models/ledger_snapshot.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import '../services/local_database.dart';
import '../services/ledger_reader.dart';
import '../services/installment_codec.dart';
import '../services/installment_generator.dart';
import 'installment_repository.dart';

class SqliteInstallmentRepository implements InstallmentRepository {
  SqliteInstallmentRepository(this.database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final LocalDatabase database;
  final DateTime Function() _now;
  DateTime get today {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Future<LedgerSnapshot> generateDue() async {
    final db = await database.database;
    return db.transaction((tx) async {
      await generateDueInstallments(tx, today);
      return readLedger(tx);
    });
  }

  @override
  Future<LedgerSnapshot> createPlan(InstallmentDraft draft) async {
    final db = await database.database;
    return db.transaction((tx) async {
      await generateDueInstallments(tx, today);
      final before = await readLedger(tx);
      final account = before.accounts
          .where((a) => a.id == draft.accountId)
          .firstOrNull;
      if (account == null ||
          account.details.type != AccountType.creditCard ||
          account.details.openingBalanceFor(draft.originalAmount.currency) ==
              null) {
        InstallmentDraft.fail(
          'account',
          'Selecciona una tarjeta de crédito con esa moneda registrada.',
        );
      }
      if (draft.referenceDate.isAfter(today)) {
        InstallmentDraft.fail(
          'referenceDate',
          'La fecha de referencia no puede ser futura.',
        );
      }
      final schedule = draft.buildSchedule();
      if (schedule.any(
        (i) =>
            !i.previouslyLoaded && i.date.isBefore(account.details.openingDate),
      )) {
        InstallmentDraft.fail(
          'firstDate',
          'Las nuevas cuotas no pueden preceder a la apertura de la tarjeta.',
        );
      }
      if (draft.categoryId != null &&
          !before.categories.any(
            (c) =>
                c.id == draft.categoryId &&
                c.details.kind == CategoryKind.expense,
          )) {
        InstallmentDraft.fail('category', 'Selecciona una categoría de gasto.');
      }
      if (draft.originalMovementId != null) {
        final original = before.movements
            .where((m) => m.id == draft.originalMovementId)
            .firstOrNull;
        if (original == null ||
            !original.details.isExpense ||
            original.details.isGenerated ||
            original.details.accountId != draft.accountId ||
            original.details.amount != draft.originalAmount ||
            original.details.date.isAfter(draft.referenceDate) ||
            before.installmentPlans.any(
              (p) => p.draft.originalMovementId == original.id,
            ) ||
            before.movements.any(
              (m) => m.details.originalMovementId == original.id,
            )) {
          InstallmentDraft.fail(
            'originalMovement',
            'Vincula una compra completa de esta tarjeta, moneda e importe, sin devoluciones ni otro plan.',
          );
        }
      }
      final id = await tx.insert('installment_plans', draftValues(draft));
      for (final row in schedule) {
        await tx.insert('installments', installmentValues(id, row));
      }
      if (draft.originalMovementId != null) {
        final futurePrincipal = schedule
            .where((i) => !i.previouslyLoaded)
            .fold(
              BigInt.zero,
              (sum, i) => sum + BigInt.from(i.principal!.minorUnits),
            );
        if (futurePrincipal > BigInt.zero) {
          await tx.insert('movements', {
            'type': 'expense',
            'account_id': draft.accountId,
            'amount_minor': futurePrincipal.toInt(),
            'currency': draft.originalAmount.currency.name,
            'occurred_on': isoDay(draft.referenceDate),
            'description': '${draft.description} · A cuotas',
            'origin': 'installmentConversion',
            'installment_plan_id': id,
            'installment_number': 0,
            'recognized_expense_minor': 0,
          });
        }
      }
      await generateDueInstallments(tx, today);
      return readLedger(tx);
    });
  }

  @override
  Future<LedgerSnapshot> cancelPlan(int id) async {
    final db = await database.database;
    return db.transaction((tx) async {
      await generateDueInstallments(tx, today);
      final snapshot = await readLedger(tx);
      final plan = snapshot.installmentPlans
          .where((p) => p.id == id)
          .firstOrNull;
      if (plan == null || plan.state != InstallmentPlanState.active) {
        InstallmentDraft.fail('plan', 'Selecciona un plan activo.');
      }
      await tx.update(
        'installment_plans',
        {'cancelled': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      await tx.insert('installment_revisions', {
        'plan_id': id,
        'recorded_on': isoDay(today),
        'note':
            'Cancelación: se detienen cargos futuros; histórico conservado.',
      });
      return readLedger(tx);
    });
  }

  @override
  Future<LedgerSnapshot> reviseFuture(
    int id, {
    required String description,
    required int? categoryId,
    required Money monthly,
    required DateTime nextDate,
    required int chargeDay,
    Money? principal,
    Money? interest,
    Money? fee,
  }) async {
    final db = await database.database;
    return db.transaction((tx) async {
      await generateDueInstallments(tx, today);
      final snapshot = await readLedger(tx);
      final plan = snapshot.installmentPlans
          .where((p) => p.id == id)
          .firstOrNull;
      if (plan == null || plan.pending.isEmpty) {
        InstallmentDraft.fail(
          'plan',
          'El plan no tiene cuotas pendientes editables.',
        );
      }
      if (monthly.currency != plan.draft.originalAmount.currency) {
        InstallmentDraft.fail(
          'currency',
          'La moneda del plan no se puede cambiar.',
        );
      }
      if (categoryId != null &&
          !snapshot.categories.any(
            (c) => c.id == categoryId && c.details.kind == CategoryKind.expense,
          )) {
        InstallmentDraft.fail('category', 'Selecciona una categoría de gasto.');
      }
      if (nextDate.isBefore(today)) {
        InstallmentDraft.fail(
          'firstDate',
          'La nueva fecha pendiente debe ser hoy o posterior.',
        );
      }
      final loaded = plan.schedule.where((row) => row.loaded).toList();
      if (loaded.isNotEmpty &&
          !DateTime(
            nextDate.year,
            nextDate.month,
          ).isAfter(DateTime(loaded.last.date.year, loaded.last.date.month))) {
        InstallmentDraft.fail(
          'firstDate',
          'El nuevo calendario debe comenzar en un mes posterior a la última cuota cargada.',
        );
      }
      final amount =
          plan.pendingPrincipal ??
          Money.fromBigInt(
            BigInt.from(monthly.minorUnits) * BigInt.from(plan.pending.length),
            monthly.currency,
          );
      final edited = InstallmentDraft(
        description: description,
        accountId: plan.draft.accountId,
        categoryId: categoryId,
        originalAmount: amount,
        count: plan.pending.length,
        monthlyAmount: monthly,
        firstDate: nextDate,
        chargeDay: chargeDay,
        previousCount: 0,
        referenceDate: today,
        costMode: plan.draft.costMode,
        limitMode: plan.draft.limitMode,
        monthlyPrincipal: principal,
        monthlyInterest: interest,
        monthlyFee: fee,
      );
      if (monthly.currency != plan.draft.originalAmount.currency) {
        InstallmentDraft.fail('currency', 'La moneda del plan se conserva.');
      }
      final rows = edited.buildSchedule();
      for (var index = 0; index < rows.length; index++) {
        final values = installmentValues(id, rows[index])
          ..remove('plan_id')
          ..remove('number');
        await tx.update(
          'installments',
          values,
          where: 'plan_id = ? AND number = ?',
          whereArgs: [id, plan.pending[index].number],
        );
      }
      await tx.update(
        'installment_plans',
        {'description': edited.description, 'category_id': categoryId},
        where: 'id = ?',
        whereArgs: [id],
      );
      await tx.insert('installment_revisions', {
        'plan_id': id,
        'recorded_on': isoDay(today),
        'note': 'Calendario pendiente actualizado; cuotas cargadas y condiciones originales conservadas.',
      });
      await generateDueInstallments(tx, today);
      return readLedger(tx);
    });
  }

  @override
  Future<LedgerSnapshot> reconcile(
    int planId,
    int number,
    int sourceMovementId,
    String reference,
  ) async {
    final db = await database.database;
    return db.transaction((tx) async {
      await generateDueInstallments(tx, today);
      final snapshot = await readLedger(tx);
      final target = snapshot.movements
          .where(
            (m) =>
                m.details.installmentPlanId == planId &&
                m.details.installmentNumber == number &&
                m.details.origin == MovementOrigin.installmentCharge,
          )
          .firstOrNull;
      final source = snapshot.movements
          .where((m) => m.id == sourceMovementId)
          .firstOrNull;
      if (reference.trim().isEmpty || reference.trim().length > 120) {
        InstallmentDraft.fail(
          'reference',
          'Escribe una referencia de conciliación de 1 a 120 caracteres.',
        );
      }
      if (target != null && source != null) {
        final existing = await tx.query(
          'installment_reconciliations',
          where: 'target_movement_id = ?',
          whereArgs: [target.id],
        );
        if (existing.isNotEmpty) {
          if (existing.single['source_movement_id'] != source.id) {
            InstallmentDraft.fail(
              'reconciliation',
              'La cuota ya tiene otro movimiento conciliado.',
            );
          }
          return snapshot;
        }
      }
      if (target == null ||
          source == null ||
          source.details.isGenerated ||
          !source.details.isExpense ||
          source.details.accountId != target.details.accountId ||
          source.details.amount != target.details.amount ||
          snapshot.installmentPlans.any(
            (p) => p.draft.originalMovementId == source.id,
          ) ||
          snapshot.movements.any(
            (m) => m.details.originalMovementId == source.id,
          )) {
        InstallmentDraft.fail(
          'reconciliation',
          'Selecciona un gasto manual/importado de la misma cuenta, moneda e importe, sin devoluciones ni otro plan.',
        );
      }
      await tx.insert('installment_reconciliations', {
        'source_movement_id': source.id,
        'target_movement_id': target.id,
        'reference': reference.trim(),
      });
      return readLedger(tx);
    });
  }
}
