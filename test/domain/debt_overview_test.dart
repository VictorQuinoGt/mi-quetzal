import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/domain/models/account.dart';
import 'package:mi_quetzal/domain/models/debt_overview.dart';
import 'package:mi_quetzal/domain/models/ledger_snapshot.dart';
import 'package:mi_quetzal/domain/models/money.dart';
import 'package:mi_quetzal/domain/models/movement.dart';
import 'package:mi_quetzal/domain/models/installment_plan.dart';

void main() {
  final today = DateTime(2026, 11, 16);
  Account card(int id, int gtq, {int? usd, DateTime? due}) => Account(
    id: id,
    details: AccountDetails(
      name: 'Tarjeta sintética $id',
      type: AccountType.creditCard,
      openingBalance: Money(gtq, Currency.gtq),
      secondaryOpeningBalance: usd == null ? null : Money(usd, Currency.usd),
      openingDate: DateTime(2026, 1, 1),
      nextPaymentDueDate: due,
    ),
  );
  test(
    'Separa deuda y saldos a favor sin compensarlos ni sumar monedas o bancos',
    () {
      final accounts = [
        card(1, 15000, usd: 1000),
        card(2, 10000),
        Account(
          id: 3,
          details: AccountDetails(
            name: 'Banco sintético',
            type: AccountType.bank,
            openingBalance: Money(999999, Currency.gtq),
            openingDate: today,
          ),
        ),
      ];
      final snapshot = LedgerSnapshot.calculate(accounts, [
        Movement(
          id: 1,
          details: MovementDetails(
            type: MovementType.creditPayment,
            accountId: 2,
            paymentFunding: PaymentFunding.externalCash,
            amount: Money(25000, Currency.gtq),
            date: today,
            description: 'Pago sintético',
          ),
        ),
      ]);
      final summary = DebtOverview.calculate(snapshot, today);
      expect(summary.cardsWithDebt, 1);
      expect(summary.cards.length, 2);
      expect(summary.currencies.first.debt, Money(15000, Currency.gtq));
      expect(summary.currencies.first.credit, Money(15000, Currency.gtq));
      expect(summary.currencies.last.debt, Money(1000, Currency.usd));
      expect(summary.currencies.last.credit.minorUnits, 0);
      expect(() => summary.cards.clear(), throwsUnsupportedError);
    },
  );
  test('Fechas futuras se ordenan; las pasadas y ausentes se conservan sin avanzar ni declarar mora', () {
    final summary = DebtOverview.calculate(
      LedgerSnapshot.calculate([
        card(1, 1, due: DateTime(2026, 12, 5)),
        card(2, 1, due: today),
        card(3, 1, due: DateTime(2026, 11, 15)),
        card(4, 0),
      ], []),
      today,
    );
    expect(summary.upcomingPayments.map((a) => a.id), [2, 1]);
    expect(summary.pastPaymentDates.single.id, 3);
    expect(
      summary.pastPaymentDates.single.details.nextPaymentDueDate,
      DateTime(2026, 11, 15),
    );
    expect(summary.missingPaymentDates, 1);
  });
  test('Cuotas futuras excluyen cargadas, anteriores, del día y planes cancelados; no alteran deuda', () {
    final draft = InstallmentDraft(
      description: 'Plan sintético',
      accountId: 1,
      originalAmount: Money(400, Currency.gtq),
      count: 4,
      monthlyAmount: Money(100, Currency.gtq),
      firstDate: DateTime(2026, 10, 16),
      chargeDay: 16,
      previousCount: 0,
      referenceDate: DateTime(2026, 10, 16),
      costMode: InstallmentCostMode.noInterest,
      limitMode: InstallmentLimitMode.ordinary,
    );
    final plan = InstallmentPlan(
      id: 1,
      draft: draft,
      originalDescription: 'Plan sintético',
      schedule: [
        Installment(
          number: 1,
          date: DateTime(2026, 10, 16),
          amount: Money(100, Currency.gtq),
          previouslyLoaded: true,
        ),
        Installment(number: 2, date: today, amount: Money(100, Currency.gtq)),
        Installment(
          number: 3,
          date: DateTime(2026, 12, 16),
          amount: Money(100, Currency.gtq),
        ),
        Installment(
          number: 4,
          date: DateTime(2027, 1, 16),
          amount: Money(100, Currency.gtq),
        ),
      ],
    );
    final cancelled = InstallmentPlan(
      id: 2,
      draft: draft,
      originalDescription: 'Cancelado sintético',
      schedule: plan.schedule,
      cancelled: true,
    );
    final summary = DebtOverview.calculate(
      LedgerSnapshot.calculate(
        [card(1, 500)],
        [],
        installmentPlans: [plan, cancelled],
      ),
      today,
    );
    expect(summary.currencies.first.debt.minorUnits, 500);
    expect(summary.currencies.first.futureInstallments.minorUnits, 200);
    expect(summary.currencies.first.installmentCount, 2);
    expect(summary.currencies.last.futureInstallments.minorUnits, 0);
  });
  test('Totales fuera de rango fallan explícitamente sin redondeo ni modificar las tarjetas', () {
    final ledger = LedgerSnapshot.calculate([
      card(1, 9007199254740991),
      card(2, 1),
    ], []);
    expect(() => DebtOverview.calculate(ledger, today), throwsArgumentError);
    expect(ledger.accounts.first.currentBalance.minorUnits, 9007199254740991);
  });
}
