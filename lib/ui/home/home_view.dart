import 'package:flutter/material.dart';

import '../../domain/models/account.dart';
import '../core/page_content.dart';
import '../movements/movements_view_model.dart';
import '../accounts/account_labels.dart';
import 'monthly_summary_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.onAccounts,
    required this.onHistory,
    required this.onOpenAccount,
    required this.viewModel,
  });
  final VoidCallback onAccounts;
  final VoidCallback onHistory;
  final ValueChanged<int> onOpenAccount;
  final MovementsViewModel viewModel;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final vm = viewModel;
      final overview = vm.debtOverview;
      final theme = Theme.of(context);
      Widget accountRow(Account account, {String? subtitle}) => ListTile(
        key: ValueKey(
          'home-account-${account.id}${subtitle == null ? '' : '-date'}',
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(account.identification),
        subtitle: Text(
          subtitle ??
              account.currentBalances
                  .map(
                    (m) =>
                        '${m.minorUnits < 0 ? m.negated.formatted : m.formatted}${m.minorUnits < 0 ? ' a favor' : ''}',
                  )
                  .join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onOpenAccount(account.id),
      );
      return PageContent(
        key: const PageStorageKey('home'),
        children: [
          Text('Resumen de deudas', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAccounts,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Ver cuentas'),
              ),
              TextButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver historial general'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (vm.status == MovementsStatus.loading)
            const Center(child: CircularProgressIndicator())
          else if (vm.status == MovementsStatus.error) ...[
            const Text('No se pudo cargar el resumen. Tus datos se conservan.'),
            OutlinedButton(onPressed: vm.load, child: const Text('Reintentar')),
          ] else if (vm.debtOverviewError != null)
            Text(vm.debtOverviewError!)
          else if (overview != null) ...[
            if (vm.loadError != null) Text(vm.loadError!),
            if (overview.cards.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Agrega tus tarjetas para consultar todas tus deudas aquí.',
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: onAccounts,
                        child: const Text('Ir a Cuentas'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Deuda total', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      for (final total in overview.currencies)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            total.debt.formatted,
                            key: ValueKey(
                              'total-debt-${total.debt.currency.name}',
                            ),
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      Text(
                        '${overview.cardsWithDebt} de ${overview.cards.length} tarjetas con deuda',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Por tarjeta', style: theme.textTheme.titleLarge),
              for (final account in overview.cards)
                Card(child: accountRow(account)),
              const SizedBox(height: 20),
              Text(
                'Próximas fechas de pago',
                style: theme.textTheme.titleLarge,
              ),
              const Text('Fechas registradas; no se avanzan automáticamente.'),
              for (final account in overview.upcomingPayments)
                Card(
                  child: accountRow(
                    account,
                    subtitle: MaterialLocalizations.of(context)
                        .formatMediumDate(account.details.nextPaymentDueDate!),
                  ),
                ),
              for (final account in overview.pastPaymentDates)
                Card(
                  child: accountRow(
                    account,
                    subtitle:
                        '${MaterialLocalizations.of(context).formatMediumDate(account.details.nextPaymentDueDate!)} · Fecha pasada, revisa la configuración',
                  ),
                ),
              if (overview.missingPaymentDates > 0)
                Text(
                  '${overview.missingPaymentDates} ${overview.missingPaymentDates == 1 ? 'tarjeta con fecha' : 'tarjetas con fecha'} sin configurar.',
                ),
              const SizedBox(height: 20),
              Text('Saldos a favor', style: theme.textTheme.titleLarge),
              const Text(
                'Se muestran separados de las deudas de otras tarjetas.',
              ),
              for (final total in overview.currencies)
                Text(
                  total.credit.formatted,
                  key: ValueKey('total-credit-${total.credit.currency.name}'),
                ),
              const SizedBox(height: 20),
              Text(
                'Cuotas futuras pendientes',
                style: theme.textTheme.titleLarge,
              ),
              const Text(
                'Compromisos aún no cargados. Se presentan separados de la deuda actual.',
              ),
              for (final total in overview.currencies)
                Text(
                  '${total.futureInstallments.formatted} · ${total.installmentCount} ${total.installmentCount == 1 ? 'cuota' : 'cuotas'}',
                  key: ValueKey(
                    'future-installments-${total.debt.currency.name}',
                  ),
                ),
            ],
          ],
          const SizedBox(height: 28),
          MonthlySummaryView(viewModel: vm),
        ],
      );
    },
  );
}
