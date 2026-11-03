import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import '../core/page_content.dart';
import 'movement_detail_view.dart';
import 'movement_row.dart';
import 'movement_filters.dart';
import 'movements_view_model.dart';

class MovementsView extends StatelessWidget {
  const MovementsView({
    super.key,
    required this.viewModel,
    required this.onCreate,
    required this.onOpenAccounts,
    required this.onManageCategories,
    required this.onCategorize,
    required this.onRefund,
  });
  final MovementsViewModel viewModel;
  final VoidCallback onCreate;
  final VoidCallback onOpenAccounts;
  final VoidCallback onManageCategories;
  final ValueChanged<Movement> onCategorize;
  final ValueChanged<Movement> onRefund;

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
          if (viewModel.status == MovementsStatus.ready) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onManageCategories,
                icon: const Icon(Icons.category_outlined),
                label: const Text('Categorías'),
              ),
            ),
            const SizedBox(height: 20),
          ],
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
          ] else ...[
            MovementFilters(viewModel: viewModel),
            if (viewModel.visibleMovements.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No hay movimientos que coincidan con los filtros.',
                  ),
                ),
              ),
            if (viewModel.visibleMovements.isNotEmpty) ...[
              Text('Estado de cuenta', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    for (final movement in viewModel.visibleMovements) ...[
                      MovementRow(
                        movement: movement,
                        category: viewModel
                            .categoryById(viewModel.categoryIdFor(movement))
                            ?.details
                            .name,
                        onDetails: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (context) => MovementDetailView(
                              movement: movement,
                              viewModel: viewModel,
                              onCategorize: () => onCategorize(movement),
                              onRefund: () => onRefund(movement),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      );
    },
  );
}
