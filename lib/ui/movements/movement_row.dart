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
    final date = MaterialLocalizations.of(context).formatMediumDate(data.date);
    final secondary =
        '$date${data.supportsCategory || data.isRefund ? ' · ${category ?? 'Sin categoría'}' : ''}';
    return Semantics(
      button: true,
      label: '${data.operationLabel}. Abrir movimiento: ${data.description}',
      child: InkWell(
        key: ValueKey('movement-${movement.id}'),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final description = Text(
                data.description,
                style: theme.textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                icon: Tooltip(
                  message: data.operationLabel,
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.type.marker,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: description),
                      open,
                    ],
                  ),
                  if (constraints.maxWidth >= 300 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 20)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            secondary,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * .55,
                          ),
                          child: amount,
                        ),
                      ],
                    )
                  else ...[
                    Text(secondary, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerRight, child: amount),
                  ],
                  const SizedBox(height: 4),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
