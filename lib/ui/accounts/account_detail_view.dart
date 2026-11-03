import 'package:flutter/material.dart';

import '../../domain/models/account.dart';
import '../../domain/models/account_activity.dart';
import '../../domain/models/movement.dart';
import '../core/page_content.dart';
import '../movements/movement_row.dart';
import '../movements/movements_view_model.dart';
import 'account_balances.dart';
import 'account_detail_view_model.dart';
import 'account_labels.dart';
import 'credit_summary.dart';
import 'installment_plan_view.dart';
import '../../domain/models/installment_plan.dart';

class AccountDetailView extends StatelessWidget {
  const AccountDetailView({
    super.key,
    required this.viewModel,
    required this.onEdit,
    required this.onLinkDebit,
    required this.onOpenAccount,
    required this.onOpenMovement,
    required this.onAddPlan,
    required this.onOpenPlan,
  });
  final AccountDetailViewModel viewModel;
  final Future<void> Function() onEdit;
  final Future<void> Function() onLinkDebit;
  final ValueChanged<AccountDetailTarget> onOpenAccount;
  final ValueChanged<Movement> onOpenMovement;
  final VoidCallback onAddPlan;
  final ValueChanged<InstallmentPlan> onOpenPlan;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final vm = viewModel;
      final account = vm.account;
      final periodMovements = vm.movements;
      final debit = vm.debitCard;
      final ready =
          vm.ledger.status == MovementsStatus.ready && account != null;
      final credit = account?.details.type == AccountType.creditCard;
      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(vm.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              onPressed: ready ? onEdit : null,
              tooltip: 'Editar ${vm.name}',
              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
            ),
          ],
        ),
        body: SafeArea(
          child: PageContent(
            key: PageStorageKey(
              'account-detail-${vm.target.kind.name}-${vm.target.id}',
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (vm.ledger.status == MovementsStatus.loading)
                const Center(child: CircularProgressIndicator())
              else if (vm.ledger.status == MovementsStatus.error) ...[
                const Text(
                  'No se pudo cargar la cuenta ni sus movimientos. Tus datos se conservan.',
                ),
                OutlinedButton.icon(
                  onPressed: vm.load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ] else if (account == null)
                const Text('Esta cuenta o tarjeta ya no está disponible.')
              else ...[
                Text(
                  '${debit == null ? account.details.type.label : 'Tarjeta de débito'}${vm.lastFour == null ? '' : ' · •••• ${vm.lastFour}'}',
                  style: theme.textTheme.titleMedium,
                ),
                if (account.details.type != AccountType.cash) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Entidad financiera: ${vm.institution ?? 'Sin especificar'}',
                  ),
                ],
                const SizedBox(height: 16),
                if (credit)
                  CreditSummary(account: account, viewModel: vm)
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: AccountBalances(
                        account: account,
                        label: debit != null
                            ? 'Saldo de cuenta vinculada'
                            : 'Saldo disponible',
                      ),
                    ),
                  ),
                if (debit != null) ...[
                  const SizedBox(height: 16),
                  Text('Cuenta bancaria vinculada: ${account.identification}'),
                  TextButton.icon(
                    onPressed: () =>
                        onOpenAccount(AccountDetailTarget.account(account.id)),
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Ver cuenta bancaria'),
                  ),
                  Text(vm.debitScope!),
                ] else if (account.details.type == AccountType.bank) ...[
                  const SizedBox(height: 16),
                  Text(
                    account.details.bankAccountType?.label ??
                        'Tipo bancario sin especificar',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tarjetas de débito vinculadas',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (vm.linkedDebitCards.isEmpty)
                    const Text('Aún no hay tarjetas vinculadas.'),
                  for (final card in vm.linkedDebitCards)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(card.details.name),
                      subtitle: Text(
                        card.details.lastFour == null
                            ? 'Tarjeta de débito'
                            : '•••• ${card.details.lastFour}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          onOpenAccount(AccountDetailTarget.debitCard(card.id)),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onLinkDebit,
                      icon: const Icon(Icons.link),
                      label: const Text('Vincular débito'),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (credit) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Movimientos'),
                        icon: Icon(Icons.receipt_long_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Cuotas'),
                        icon: Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                    selected: {vm.showInstallments},
                    onSelectionChanged: (values) =>
                        vm.selectInstallments(values.single),
                  ),
                  const SizedBox(height: 16),
                ],
                if (credit && vm.showInstallments) ...[
                  FilledButton.icon(
                    onPressed: onAddPlan,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar compra en cuotas'),
                  ),
                  const SizedBox(height: 16),
                  if (vm.plans.isEmpty)
                    const Text('No hay planes de cuotas en esta tarjeta.'),
                  for (final plan in vm.plans) ...[
                    Card(
                      child: ListTile(
                        title: Text(plan.draft.description),
                        subtitle: Text(
                          '${(plan.pending.isEmpty ? plan.draft.monthlyAmount : plan.pending.first.amount).compact} mensual\n${plan.loadedCount} de ${plan.schedule.length} cuotas cargadas\nPendiente de cargar: ${plan.pendingAmount.compact}\nSiguiente: ${plan.nextDate == null ? 'Sin cargos pendientes' : MaterialLocalizations.of(context).formatMediumDate(plan.nextDate!)} · ${planStateLabel(plan.state)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onOpenPlan(plan),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ] else ...[
                  Text(
                    'Movimientos del período',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _PeriodControls(viewModel: vm),
                  const SizedBox(height: 12),
                  Text(
                    MaterialLocalizations.of(context)
                        .formatMonthYear(vm.selectedMonth),
                    style: theme.textTheme.titleMedium,
                  ),
                  const Text(
                    'Mes calendario; no representa un ciclo de corte bancario.',
                  ),
                  const SizedBox(height: 12),
                  if (periodMovements.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No hay movimientos en este período.'),
                      ),
                    )
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final movement in periodMovements) ...[
                            MovementRow(
                              movement: movement,
                              category: vm.ledger
                                  .categoryById(
                                    vm.ledger.categoryIdFor(movement),
                                  )
                                  ?.details
                                  .name,
                              onDetails: () => onOpenMovement(movement),
                            ),
                            if (movement.id != periodMovements.last.id)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _PeriodControls extends StatelessWidget {
  const _PeriodControls({required this.viewModel});
  final AccountDetailViewModel viewModel;
  static const months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Column(
      children: [
        DropdownButtonFormField<AccountPeriod>(
          initialValue: vm.period,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Período',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: AccountPeriod.currentMonth,
              child: Text('Mes actual'),
            ),
            DropdownMenuItem(
              value: AccountPeriod.previousMonth,
              child: Text('Mes anterior'),
            ),
            DropdownMenuItem(
              value: AccountPeriod.history,
              child: Text('Histórico'),
            ),
          ],
          onChanged: (value) {
            if (value != null) vm.selectPeriod(value);
          },
        ),
        if (vm.period == AccountPeriod.history) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('history-year-${vm.selectedMonth.year}'),
                  initialValue: vm.selectedMonth.year,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Año',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (var year = vm.latestYear; year >= 1900; year--)
                      DropdownMenuItem(value: year, child: Text('$year')),
                  ],
                  onChanged: (value) {
                    if (value != null) vm.selectHistoryYear(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey(
                    'history-month-${vm.selectedMonth.year}-${vm.selectedMonth.month}',
                  ),
                  initialValue: vm.selectedMonth.month,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mes',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final month in vm.availableMonths)
                      DropdownMenuItem(
                        value: month,
                        child: Text(
                          months[month - 1],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      vm.selectHistory(vm.selectedMonth.year, value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
