import 'package:flutter/material.dart';

import '../../domain/models/account.dart';
import '../../domain/models/debit_card.dart';
import '../../domain/models/money.dart';
import '../core/page_content.dart';
import 'account_labels.dart';
import 'accounts_view_model.dart';

class AccountsView extends StatelessWidget {
  const AccountsView({
    super.key,
    required this.viewModel,
    required this.onCreate,
    required this.onLinkDebitCard,
    required this.onEdit,
    required this.onEditDebit,
    required this.onManageInstitutions,
  });
  final AccountsViewModel viewModel;
  final VoidCallback onCreate;
  final VoidCallback onLinkDebitCard;
  final ValueChanged<Account> onEdit;
  final ValueChanged<DebitCard> onEditDebit;
  final VoidCallback onManageInstitutions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final theme = Theme.of(context);
      final credits = viewModel.accounts.where(
        (a) => a.details.type == AccountType.creditCard,
      );
      final cash = viewModel.accounts.where(
        (a) => a.details.type == AccountType.cash,
      );
      return PageContent(
        children: [
          Text('Cuentas y tarjetas', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Tus saldos actuales, con quetzales y dólares por separado.',
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onManageInstitutions,
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('Entidades financieras'),
              ),
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
              ),
            if (credits.isNotEmpty) ...[
              const _SectionTitle('Tarjetas de crédito'),
              for (final account in credits) ...[
                _AccountCard(
                  account: account,
                  institution: viewModel
                      .institutionById(account.details.financialInstitutionId)
                      ?.details
                      .name,
                  onEdit: () => onEdit(account),
                ),
                const SizedBox(height: 16),
              ],
            ],
            if (viewModel.debitCards.isNotEmpty) ...[
              const _SectionTitle('Tarjetas de débito'),
              for (final card in viewModel.debitCards) ...[
                _DebitCard(
                  card: card,
                  bank: viewModel.accountById(card.details.accountId)!,
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
                  onEdit: () => onEditDebit(card),
                ),
                const SizedBox(height: 16),
              ],
            ],
            const _SectionTitle('Cuentas bancarias'),
            if (viewModel.bankAccounts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text('Aún no tienes cuentas bancarias.'),
              ),
            for (final account in viewModel.bankAccounts) ...[
              _AccountCard(
                account: account,
                institution: viewModel
                    .institutionById(account.details.financialInstitutionId)
                    ?.details
                    .name,
                onEdit: () => onEdit(account),
              ),
              const SizedBox(height: 16),
            ],
            if (cash.isNotEmpty) ...[
              const _SectionTitle('Efectivo'),
              for (final account in cash) ...[
                _AccountCard(account: account, onEdit: () => onEdit(account)),
                const SizedBox(height: 16),
              ],
            ],
          ],
        ],
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 16),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onEdit,
    this.institution,
  });
  final Account account;
  final String? institution;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final details = account.details;
    final credit = details.type == AccountType.creditCard;
    return _FinancialCard(
      key: ValueKey('account-${account.id}'),
      title: details.name,
      subtitle:
          '${details.type.label}${details.lastFour == null ? '' : ' · •••• ${details.lastFour}'}',
      icon: credit
          ? Icons.credit_card
          : details.type == AccountType.bank
          ? Icons.account_balance_outlined
          : Icons.payments_outlined,
      onEdit: onEdit,
      children: [
        if (details.type != AccountType.cash) ...[
          Text('Entidad financiera: ${institution ?? 'Sin especificar'}'),
          const SizedBox(height: 12),
        ],
        if (details.type == AccountType.bank) ...[
          Text(
            details.bankAccountType?.label ?? 'Tipo bancario sin especificar',
          ),
          const SizedBox(height: 12),
        ],
        for (final balance in account.currentBalances) ...[
          _Balance(balance: balance, credit: credit),
          if (details.type == AccountType.cash) ...[
            const SizedBox(height: 8),
            Text(
              'Saldo inicial: ${details.openingBalance.formatted} · ${MaterialLocalizations.of(context).formatMediumDate(details.openingDate)}',
            ),
          ],
          const SizedBox(height: 16),
        ],
        if (credit && details.secondaryOpeningBalance == null)
          Text(
            '${details.openingBalance.currency == Currency.gtq ? 'USD' : 'GTQ'} sin registrar · Añádelo al editar',
          ),
        if (details.creditLimit case final limit?) ...[
          const Divider(height: 24),
          Text('Límite de crédito: ${limit.formatted}'),
        ],
        if (details.secondaryCreditLimit case final limit?) ...[
          const SizedBox(height: 8),
          Text('Límite de crédito: ${limit.formatted}'),
        ],
      ],
    );
  }
}

class _DebitCard extends StatelessWidget {
  const _DebitCard({
    required this.card,
    required this.bank,
    required this.onEdit,
    this.institution,
  });
  final DebitCard card;
  final String? institution;
  final Account bank;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => _FinancialCard(
    key: ValueKey('debit-${card.id}'),
    title: card.details.name,
    icon: Icons.credit_card,
    subtitle:
        'Tarjeta de débito${card.details.lastFour == null ? '' : ' · •••• ${card.details.lastFour}'}',
    onEdit: onEdit,
    children: [
      Text('Entidad financiera: ${institution ?? 'Sin especificar'}'),
      const SizedBox(height: 12),
      _Balance(balance: bank.currentBalance, credit: false),
    ],
  );
}

class _Balance extends StatelessWidget {
  const _Balance({required this.balance, required this.credit});
  final Money balance;
  final bool credit;
  @override
  Widget build(BuildContext context) {
    final inFavor = credit && balance.minorUnits < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          inFavor ? 'Saldo a favor' : 'Saldo actual',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          (inFavor ? balance.absolute : balance).formatted,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }
}

class _FinancialCard extends StatelessWidget {
  const _FinancialCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onEdit,
    required this.children,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onEdit;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Editar $title',
                  icon: Icon(
                    Icons.edit_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(subtitle),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
