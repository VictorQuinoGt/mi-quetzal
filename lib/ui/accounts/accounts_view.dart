import 'package:flutter/material.dart';

import '../../domain/models/account.dart';
import '../core/page_content.dart';
import 'account_labels.dart';
import 'accounts_view_model.dart';

class AccountsView extends StatelessWidget {
  const AccountsView({
    super.key,
    required this.viewModel,
    required this.onCreate,
    required this.onLinkDebitCard,
  });

  final AccountsViewModel viewModel;
  final VoidCallback onCreate;
  final VoidCallback onLinkDebitCard;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final theme = Theme.of(context);
        return PageContent(
          children: [
            Text('Cuentas y tarjetas', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Registra tus saldos iniciales y conserva cada moneda por separado.',
            ),
            const SizedBox(height: 24),
            if (viewModel.status == AccountsStatus.loading)
              const Center(child: CircularProgressIndicator())
            else if (viewModel.status == AccountsStatus.error) ...[
              const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 12),
              const Text(
                'No se pudieron cargar tus cuentas. Tus datos no se han borrado.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: viewModel.load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: viewModel.bankAccounts.isEmpty
                      ? null
                      : onLinkDebitCard,
                  icon: const Icon(Icons.link),
                  label: const Text('Vincular débito'),
                ),
              ),
              if (viewModel.bankAccounts.isEmpty)
                const Text(
                  'Para vincular débito, primero crea una cuenta bancaria.',
                ),
              const SizedBox(height: 20),
              if (viewModel.accounts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aquí comenzará tu organización',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Agrega tu primera cuenta de efectivo, bancaria o tarjeta de crédito.',
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add),
                          label: const Text('Nueva cuenta'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final account in viewModel.accounts) ...[
                  _AccountCard(account: account),
                  const SizedBox(height: 16),
                ],
              const SizedBox(height: 20),
              if (viewModel.debitCards.isNotEmpty) ...[
                Text('Tarjetas de débito', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                for (final card in viewModel.debitCards) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.details.name,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Débito${card.details.lastFour == null ? '' : ' · •••• ${card.details.lastFour}'}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vinculada a: ${viewModel.accountById(card.details.accountId)!.details.name}',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Comparte el saldo y la moneda de su cuenta bancaria.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              const Text(
                'Los saldos se calculan con la apertura y todos los movimientos registrados. Las tarjetas de débito no tienen fondos independientes.',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final details = account.details;
    final theme = Theme.of(context);
    final credit = details.type == AccountType.creditCard;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  credit
                      ? Icons.credit_card
                      : details.type == AccountType.cash
                      ? Icons.payments_outlined
                      : Icons.account_balance_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(details.name, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${details.type.label}${details.lastFour == null ? '' : ' · •••• ${details.lastFour}'}',
            ),
            const SizedBox(height: 20),
            Text(
              account.hasCreditInFavor
                  ? 'Saldo a favor'
                  : credit
                  ? 'Deuda actual'
                  : 'Saldo actual',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              account.displayBalance.formatted,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${credit ? 'Deuda' : 'Saldo'} inicial: ${details.openingBalance.formatted} · ${MaterialLocalizations.of(context).formatMediumDate(details.openingDate)}',
            ),
            if (details.creditLimit case final limit?) ...[
              const Divider(height: 32),
              Text('Límite de crédito: ${limit.formatted}'),
            ],
          ],
        ),
      ),
    );
  }
}
