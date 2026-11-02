import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import '../core/page_content.dart';
import 'movement_labels.dart';
import 'movements_view_model.dart';

class MovementsView extends StatelessWidget {
  const MovementsView({
    super.key,
    required this.viewModel,
    required this.onCreate,
    required this.onOpenAccounts,
  });
  final MovementsViewModel viewModel;
  final VoidCallback onCreate;
  final VoidCallback onOpenAccounts;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final theme = Theme.of(context);
      return PageContent(
        children: [
          Text('Tus movimientos', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Compras, ingresos y transferencias con sus cuentas vinculadas.',
          ),
          const SizedBox(height: 24),
          if (viewModel.status == MovementsStatus.loading)
            const Center(child: CircularProgressIndicator())
          else if (viewModel.status == MovementsStatus.error) ...[
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar el historial. Tus datos no se han borrado.',
            ),
            OutlinedButton.icon(
              onPressed: viewModel.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ] else if (viewModel.movements.isEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tu historial empieza aquí',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      viewModel.accounts.isEmpty
                          ? 'Primero agrega una cuenta para registrar tus operaciones.'
                          : 'Registra tu primer movimiento para actualizar tus saldos.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: viewModel.accounts.isEmpty
                          ? onOpenAccounts
                          : onCreate,
                      icon: const Icon(Icons.add),
                      label: Text(
                        viewModel.accounts.isEmpty
                            ? 'Ir a Cuentas'
                            : 'Nuevo movimiento',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            for (final movement in viewModel.movements) ...[
              _MovementCard(movement: movement, viewModel: viewModel),
              const SizedBox(height: 16),
            ],
        ],
      );
    },
  );
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement, required this.viewModel});
  final Movement movement;
  final MovementsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final details = movement.details;
    final origin = viewModel.accountById(details.accountId)!;
    final other = viewModel.accountById(details.counterpartyAccountId);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details.type.label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(details.description, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              details.amount.formatted,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${origin.details.name}${other == null ? '' : ' → ${other.details.name}'}',
            ),
            const SizedBox(height: 4),
            Text(
              MaterialLocalizations.of(context).formatMediumDate(details.date),
            ),
            if (details.type == MovementType.transfer ||
                details.type == MovementType.creditPayment) ...[
              const SizedBox(height: 8),
              const Text('Transferencia · No suma ingresos ni gastos'),
            ],
          ],
        ),
      ),
    );
  }
}
