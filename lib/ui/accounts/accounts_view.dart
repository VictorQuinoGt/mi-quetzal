import 'package:flutter/material.dart';

import '../../domain/models/account.dart';
import '../../domain/models/account_activity.dart';
import '../core/page_content.dart';
import 'account_balances.dart';
import 'account_labels.dart';
import 'accounts_view_model.dart';

class AccountsView extends StatelessWidget {
  const AccountsView({
    super.key,
    required this.viewModel,
    required this.onCreate,
    required this.onOpen,
    required this.onManageInstitutions,
  });
  final AccountsViewModel viewModel;
  final VoidCallback onCreate;
  final ValueChanged<AccountDetailTarget> onOpen;
  final VoidCallback onManageInstitutions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final theme = Theme.of(context);
      return PageContent(
        key: const PageStorageKey('accounts-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text('Cuentas y tarjetas', style: theme.textTheme.headlineSmall),
              FilledButton.tonalIcon(
                onPressed: viewModel.status == AccountsStatus.ready
                    ? onCreate
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Agregar cuenta'),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('account-admin'),
                tooltip: 'Administrar cuentas',
                onSelected: (_) => onManageInstitutions(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'institutions',
                    child: Text('Entidades financieras'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (viewModel.status == AccountsStatus.loading)
            const Center(child: CircularProgressIndicator())
          else if (viewModel.status == AccountsStatus.error) ...[
            const Text(
              'No se pudieron cargar tus cuentas. Tus datos no se han borrado.',
            ),
            OutlinedButton.icon(
              onPressed: viewModel.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ] else if (viewModel.accounts.isEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aquí comenzará tu organización',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Agrega tu primera cuenta de efectivo, bancaria o tarjeta de crédito.',
                    ),
                    TextButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            for (final type in [
              AccountType.creditCard,
              AccountType.bank,
              AccountType.cash,
            ]) ...[
              if (type == AccountType.bank &&
                  viewModel.debitCards.isNotEmpty) ...[
                const _Heading('Tarjetas de débito'),
                for (final card in viewModel.debitCards) ...[
                  _SummaryCard(
                    key: ValueKey('debit-${card.id}'),
                    name: card.details.name,
                    institution: viewModel
                        .institutionById(
                          card.details.financialInstitutionId ??
                              viewModel
                                  .accountById(card.details.accountId)!
                                  .details
                                  .financialInstitutionId,
                        )
                        ?.details
                        .name,
                    type:
                        'Tarjeta de débito${card.details.lastFour == null ? '' : ' · •••• ${card.details.lastFour}'}',
                    icon: Icons.credit_card_outlined,
                    account: viewModel.accountById(card.details.accountId)!,
                    label: 'Saldo de cuenta vinculada',
                    onTap: () => onOpen(AccountDetailTarget.debitCard(card.id)),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              if (viewModel.accounts.any((a) => a.details.type == type)) ...[
                _Heading(switch (type) {
                  AccountType.creditCard => 'Tarjetas de crédito',
                  AccountType.bank => 'Cuentas bancarias',
                  AccountType.cash => 'Efectivo',
                }),
                for (final account in viewModel.accounts.where(
                  (a) => a.details.type == type,
                )) ...[
                  _SummaryCard(
                    key: ValueKey('account-${account.id}'),
                    name: account.details.name,
                    institution: viewModel
                        .institutionById(account.details.financialInstitutionId)
                        ?.details
                        .name,
                    type:
                        '${type.label}${account.details.bankAccountType == null ? '' : ' · ${account.details.bankAccountType!.label}'}${account.details.lastFour == null ? '' : ' · •••• ${account.details.lastFour}'}',
                    icon: switch (type) {
                      AccountType.creditCard => Icons.credit_card_outlined,
                      AccountType.bank => Icons.account_balance_outlined,
                      AccountType.cash => Icons.payments_outlined,
                    },
                    account: account,
                    label: type == AccountType.creditCard
                        ? 'Deuda actual'
                        : 'Saldo disponible',
                    onTap: () =>
                        onOpen(AccountDetailTarget.account(account.id)),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ],
        ],
      );
    },
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.name,
    required this.institution,
    required this.type,
    required this.icon,
    required this.account,
    required this.label,
    required this.onTap,
  });
  final String name;
  final String? institution;
  final String type;
  final IconData icon;
  final Account account;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Abrir $name',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (institution != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: Tooltip(
                          message: institution!,
                          child: Text(
                            institution!,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                Text(type, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                AccountBalances(account: account, label: label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
