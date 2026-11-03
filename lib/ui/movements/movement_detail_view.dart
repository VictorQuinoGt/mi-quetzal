import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import '../core/page_content.dart';
import 'movement_labels.dart';
import 'movements_view_model.dart';

class MovementDetailView extends StatelessWidget {
  const MovementDetailView({
    super.key,
    required this.movement,
    required this.viewModel,
    required this.onCategorize,
    required this.onRefund,
  });
  final Movement movement;
  final MovementsViewModel viewModel;
  final VoidCallback onCategorize;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final current = viewModel.movementById(movement.id) ?? movement;
      final details = current.details;
      final origin = viewModel.accountById(details.accountId)!;
      final other = viewModel.accountById(details.counterpartyAccountId);
      final debitCard = viewModel.debitCardById(details.debitCardId);
      final institutionId =
          debitCard?.details.financialInstitutionId ??
          origin.details.financialInstitutionId;
      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle del movimiento')),
        body: SafeArea(
          child: PageContent(
            children: [
              Text(details.operationLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 12),
              Text(details.description, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text(
                details.amount.formatted,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                MaterialLocalizations.of(context)
                    .formatMediumDate(details.date),
              ),
              const Divider(height: 32),
              if (details.isGenerated) ...[
                Text(
                  'Plan ${details.installmentPlanId} · ${details.origin == MovementOrigin.installmentCharge ? 'Cuota ${details.installmentNumber}' : 'Reclasificación de capital futuro'}',
                ),
                Text(
                  details.reconciled
                      ? 'Cargo conciliado con registro bancario'
                      : 'Generado por la app · Pendiente de conciliación',
                ),
                const Text(
                  'Registro de control personal; no ejecuta cobros bancarios.',
                ),
                if (details.origin == MovementOrigin.installmentCharge)
                  Text(
                    'Gasto reconocido en este cargo: ${details.reportExpense.compact}',
                  ),
                const SizedBox(height: 16),
              ],
              if (details.reconciledIntoId != null)
                Text(
                  'Referencia vinculada al movimiento ${details.reconciledIntoId}. No vuelve a sumar deuda ni gasto.',
                ),
              Text(
                'Cuenta: ${origin.details.name}${origin.details.lastFour == null ? '' : ' · •••• ${origin.details.lastFour}'}',
              ),
              if (other != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Destino: ${other.details.name}${other.details.lastFour == null ? '' : ' · •••• ${other.details.lastFour}'}',
                ),
                Text(
                  'Entidad de destino: ${viewModel.institutionById(other.details.financialInstitutionId)?.details.name ?? 'Sin especificar'}',
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Entidad financiera: ${viewModel.institutionById(institutionId)?.details.name ?? 'Sin especificar'}',
              ),
              if (debitCard != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Débito: ${debitCard.details.name}${debitCard.details.lastFour == null ? '' : ' · •••• ${debitCard.details.lastFour}'}',
                ),
              ],
              if (details.isExpense ||
                  details.isIncome ||
                  details.isRefund) ...[
                const SizedBox(height: 16),
                Text(
                  'Categoría: ${viewModel.categoryById(viewModel.categoryIdFor(current))?.details.name ?? 'Sin categoría'}',
                ),
                if (!details.isRefund)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onCategorize,
                      icon: const Icon(Icons.label_outline),
                      label: const Text('Categorizar'),
                    ),
                  ),
              ],
              if (details.isExpense && !details.isGenerated) ...[
                const SizedBox(height: 16),
                Text(
                  'Pendiente de devolver: ${viewModel.remainingRefund(current).formatted}',
                ),
                if (viewModel.remainingRefund(current).minorUnits > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onRefund,
                      icon: const Icon(Icons.undo),
                      label: const Text('Devolver'),
                    ),
                  )
                else
                  const Text('Compra devuelta por completo'),
              ],
              if (details.isRefund) ...[
                const SizedBox(height: 16),
                Text(
                  'Compra original: ${viewModel.movementById(details.originalMovementId)!.details.description}',
                ),
                const Text('Revierte gasto · No suma ingresos'),
              ],
              if (details.type == MovementType.transfer ||
                  details.type == MovementType.creditPayment) ...[
                const SizedBox(height: 16),
                const Text('Transferencia · No suma ingresos ni gastos'),
              ],
            ],
          ),
        ),
      );
    },
  );
}
