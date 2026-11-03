import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import 'movement_labels.dart';

class MovementRow extends StatelessWidget {
  const MovementRow({
    super.key,
    required this.movement,
    required this.onDetails,
    this.category,
  });
  final Movement movement;
  final String? category;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) {
    final data = movement.details;
    final theme = Theme.of(context);
    final icon = switch (data.type) {
      MovementType.expense => Icons.shopping_bag_outlined,
      MovementType.income => Icons.south_west,
      MovementType.transfer => Icons.swap_horiz,
      MovementType.creditPayment => Icons.credit_score_outlined,
      MovementType.refund => Icons.undo,
    };
    final date = MaterialLocalizations.of(context).formatMediumDate(data.date);
    final secondary =
        '$date · ${category ?? (data.isExpense || data.isIncome || data.isRefund ? 'Sin categoría' : data.type.label)}';
    return Semantics(
      button: true,
      label: 'Abrir movimiento: ${data.description}',
      child: InkWell(
        key: ValueKey('movement-${movement.id}'),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final description = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.description,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(secondary, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Icon(icon, size: 16, color: theme.colorScheme.primary),
                      Text(
                        data.operationLabel,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              );
              final amount = Text(
                data.amount.formatted,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall,
              );
              final open = IconButton(
                key: ValueKey('movement-detail-${movement.id}'),
                onPressed: onDetails,
                tooltip: 'Abrir movimiento: ${data.description}',
                icon: const Icon(Icons.chevron_right),
              );
              if (constraints.maxWidth >= 480 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21) {
                return Row(
                  children: [
                    Expanded(child: description),
                    const SizedBox(width: 12),
                    Flexible(child: amount),
                    open,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: description),
                      open,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: amount),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
