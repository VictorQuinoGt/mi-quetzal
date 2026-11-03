import '../rules/movement_rules.dart';
import 'account.dart';
import 'category.dart';
import 'debit_card.dart';
import 'movement.dart';
import 'financial_institution.dart';
import 'installment_plan.dart';
import 'money.dart';

final class LedgerSnapshot {
  LedgerSnapshot.calculate(
    List<Account> accounts,
    List<Movement> movements, {
    List<DebitCard> debitCards = const [],
    List<Category> categories = const [],
    List<FinancialInstitution> financialInstitutions = const [],
    List<InstallmentPlan> installmentPlans = const [],
  }) {
    for (final account in accounts) {
      account.details.validateFinancialInstitution(financialInstitutions);
    }
    for (final card in debitCards) {
      card.details.validateAccount(accounts);
      card.details.validateFinancialInstitution(financialInstitutions);
    }
    final balances = {
      for (final account in accounts)
        for (final balance in account.details.openingBalances)
          (account.id, balance.currency): balance,
    };
    final ordinary = Map<(int, Currency), Money>.from(balances);
    final reserved = <(int, Currency), Money>{};
    final unknown = <(int, Currency)>{};
    final additionalLoaded = <(int, Currency)>{};
    final plansById = {for (final plan in installmentPlans) plan.id: plan};
    for (final plan in installmentPlans) {
      final matches = accounts.where((a) => a.id == plan.draft.accountId);
      if (matches.isEmpty ||
          matches.single.details.type != AccountType.creditCard ||
          matches.single.details.openingBalanceFor(
                plan.draft.originalAmount.currency,
              ) ==
              null) {
        throw const InstallmentValidationException(
          'account',
          'La tarjeta y moneda del plan deben permanecer registradas.',
        );
      }
      if (plan.draft.categoryId != null &&
          !categories.any(
            (c) =>
                c.id == plan.draft.categoryId &&
                c.details.kind == CategoryKind.expense,
          )) {
        throw const InstallmentValidationException(
          'category',
          'La categoría del plan debe ser de gasto.',
        );
      }
      final key = (plan.draft.accountId, plan.draft.originalAmount.currency);
      if (plan.draft.limitMode == InstallmentLimitMode.additional &&
          plan.draft.previousCount > 0) {
        unknown.add(key);
      }
      if (plan.draft.limitMode == InstallmentLimitMode.ordinary &&
          plan.pending.isNotEmpty) {
        final principal = plan.pendingPrincipal;
        if (principal == null) {
          unknown.add(key);
        } else {
          reserved[key] = (reserved[key] ?? Money(0, key.$2)).add(principal);
        }
      }
    }
    final chronological = [...movements]
      ..sort((a, b) {
        final dateOrder = a.details.date.compareTo(b.details.date);
        return dateOrder == 0 ? a.id.compareTo(b.id) : dateOrder;
      });
    final processed = <Movement>[];
    for (final movement in chronological) {
      final metadata = movement.details;
      if (metadata.reconciledIntoId != null) {
        final target = movements.where(
          (m) => m.id == metadata.reconciledIntoId,
        );
        if (target.isEmpty ||
            target.single.details.origin != MovementOrigin.installmentCharge ||
            target.single.details.accountId != metadata.accountId ||
            target.single.details.amount != metadata.amount ||
            metadata.isGenerated) {
          throw const MovementValidationException(
            'reconciliation',
            'La conciliación no coincide con el cargo generado.',
          );
        }
      }
      final plan = plansById[metadata.installmentPlanId];
      if (metadata.isGenerated &&
          (plan == null ||
              plan.draft.accountId != metadata.accountId ||
              plan.draft.originalAmount.currency != metadata.amount.currency)) {
        throw const MovementValidationException(
          'installment',
          'No se encontró el plan compatible con el cargo.',
        );
      }
      final effects = MovementRules.effects(
        movement.details,
        accounts,
        debitCards: debitCards,
        categories: categories,
        movements: processed,
      );
      for (final entry in effects.entries) {
        try {
          final key = (entry.key, entry.value.currency);
          final balance = balances[key]!.add(entry.value);
          final account = accounts.firstWhere((a) => a.id == entry.key);
          if (account.details.type == AccountType.cash &&
              balance.minorUnits < 0) {
            throw const MovementValidationException(
              'amount',
              'El efectivo no puede quedar negativo. Revisa el importe y las fechas de tus operaciones.',
            );
          }
          balances[key] = balance;
          if (plan?.draft.limitMode == InstallmentLimitMode.additional &&
              metadata.origin == MovementOrigin.installmentCharge) {
            additionalLoaded.add(key);
          } else {
            if (metadata.type == MovementType.creditPayment &&
                additionalLoaded.contains(key)) {
              unknown.add(key);
            }
            ordinary[key] = ordinary[key]!.add(entry.value);
          }
        } on ArgumentError {
          throw const MovementValidationException(
            'amount',
            'La operación excede el rango de saldos admitido.',
          );
        }
      }
      processed.add(movement);
    }
    this.accounts = List.unmodifiable([
      for (final account in accounts)
        Account(
          id: account.id,
          details: account.details,
          reservedCredit: {
            for (final entry in reserved.entries.where(
              (e) => e.key.$1 == account.id,
            ))
              entry.key.$2: entry.value,
          },
          ordinaryDebt: {
            for (final entry in ordinary.entries.where(
              (e) => e.key.$1 == account.id,
            ))
              entry.key.$2: entry.value,
          },
          unknownAvailable: {
            for (final key in unknown.where((k) => k.$1 == account.id)) key.$2,
          },
          currentBalance:
              balances[(account.id, account.details.openingBalance.currency)],
          secondaryCurrentBalance:
              account.details.secondaryOpeningBalance == null
              ? null
              : balances[(
                  account.id,
                  account.details.secondaryOpeningBalance!.currency,
                )],
        ),
    ]);
    this.movements = List.unmodifiable(chronological.reversed);
    this.debitCards = List.unmodifiable(debitCards);
    this.categories = List.unmodifiable(categories);
    this.financialInstitutions = List.unmodifiable(financialInstitutions);
    this.installmentPlans = List.unmodifiable(installmentPlans);
  }

  late final List<Account> accounts;
  late final List<Movement> movements;
  late final List<DebitCard> debitCards;
  late final List<Category> categories;
  late final List<FinancialInstitution> financialInstitutions;
  late final List<InstallmentPlan> installmentPlans;
}
