import 'package:flutter/material.dart';

import 'installment_plan_view_model.dart';
import '../../domain/models/installment_plan.dart';
import '../../domain/models/movement.dart';
import '../core/page_content.dart';

String planStateLabel(InstallmentPlanState state) => switch (state) {
  InstallmentPlanState.active => 'Activo',
  InstallmentPlanState.completed => 'Completado',
  InstallmentPlanState.cancelled => 'Cancelado',
};

class InstallmentPlanView extends StatefulWidget {
  const InstallmentPlanView({
    super.key,
    required this.viewModel,
    required this.onEdit,
    required this.onOpenMovement,
  });
  final InstallmentPlanViewModel viewModel;

  final Future<void> Function(InstallmentPlan) onEdit;
  final ValueChanged<Movement> onOpenMovement;
  @override
  State<InstallmentPlanView> createState() => _InstallmentPlanViewState();
}

class _InstallmentPlanViewState extends State<InstallmentPlanView> {
  bool get busy => widget.viewModel.busy;
  String? get error => widget.viewModel.error;
  Future<void> reconcile(Installment row) async {
    final reference = TextEditingController();
    int? source;
    final candidates = widget.viewModel.reconciliationCandidates(row);
    final selected = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Conciliar cuota ${row.number}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vincula únicamente el mismo cargo bancario. Se conservan ambas referencias y se cuenta una sola deuda/gasto. No se eligen coincidencias automáticamente.',
                ),
                const SizedBox(height: 16),
                if (candidates.isEmpty)
                  const Text(
                    'No hay gastos manuales/importados compatibles. Registra el cargo bancario y vuelve aquí; la importación de archivos aún no está disponible.',
                  ),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: source,
                  decoration: const InputDecoration(
                    labelText: 'Movimiento bancario ya registrado',
                  ),
                  items: [
                    for (final m in candidates)
                      DropdownMenuItem(
                        value: m.id,
                        child: Text(
                          '#${m.id} · ${m.details.description}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => update(() => source = value),
                ),
                TextField(
                  controller: reference,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Referencia de conciliación',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: source == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Vincular sin duplicar'),
            ),
          ],
        ),
      ),
    );
    final text = reference.text;
    reference.dispose();
    if (selected == true && source != null) {
      await widget.viewModel.reconcile(row.number, source!, text);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final plan = widget.viewModel.plan;
      return PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Detalle de compra en cuotas'),
            automaticallyImplyLeading: !busy,
            actions: [
              if (plan != null && plan.pending.isNotEmpty)
                IconButton(
                  tooltip: 'Editar cuotas pendientes',
                  onPressed: busy ? null : () => widget.onEdit(plan),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: SafeArea(
            child: PageContent(
              children: [
                if (plan == null)
                  const Text('El plan no está disponible.')
                else ...[
                  Text(
                    plan.draft.description,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Estado: ${planStateLabel(plan.state)}'),
                  Text(
                    '${plan.loadedCount} de ${plan.schedule.length} cuotas cargadas',
                  ),
                  Text(
                    'Original: ${plan.draft.originalAmount.compact} · ${plan.draft.count} cuotas',
                  ),
                  Text('Descripción original: ${plan.originalDescription}'),
                  Text(
                    'Mensualidad original: ${plan.draft.monthlyAmount.compact}',
                  ),
                  Text(
                    'Primera fecha original: ${MaterialLocalizations.of(context).formatFullDate(plan.draft.firstDate)} · Día mensual original: ${plan.draft.chargeDay}',
                  ),
                  Text(widget.viewModel.originalCostLabel),
                  Text(
                    'Referencia inicial: ${MaterialLocalizations.of(context).formatFullDate(plan.draft.referenceDate)} · ${plan.draft.previousCount} cuotas previamente cargadas',
                  ),
                  Text(
                    plan.draft.limitMode == InstallmentLimitMode.ordinary
                        ? 'Utiliza límite ordinario'
                        : 'Línea adicional',
                  ),
                  Text('Pendiente de cargar: ${plan.pendingAmount.compact}'),
                  if (plan.nextDate != null)
                    Text(
                      'Siguiente cargo: ${MaterialLocalizations.of(context).formatFullDate(plan.nextDate!)}',
                    ),
                  if (plan.draft.originalMovementId != null)
                    const Text(
                      'Compra completa vinculada: el capital no se vuelve a reconocer como gasto. La conversión reclasifica la deuda futura.',
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cargos de control personal generados por la app, pendientes de conciliación. No ejecutan cobros bancarios. Cuotas cargadas no significa cuotas pagadas.',
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Calendario de cuotas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final row in plan.schedule) ...[
                    const Divider(),
                    Text(
                      'Cuota ${row.number} · ${row.amount.compact}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      MaterialLocalizations.of(context)
                          .formatFullDate(row.date),
                    ),
                    Text(
                      row.previouslyLoaded
                          ? 'Previamente cargada · Sin movimiento histórico inventado'
                          : row.movementId != null
                          ? 'Generada por la app'
                          : plan.cancelled
                          ? 'Cargo futuro detenido'
                          : 'Pendiente de cargar',
                    ),
                    if (row.principal == null)
                      const Text('Capital, interés y comisión no informados')
                    else
                      Text(
                        'Capital ${row.principal!.compact} · Interés ${row.interest!.compact} · Comisión ${row.fee!.compact}',
                      ),
                    if (row.movementId != null) ...[
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => widget.onOpenMovement(
                                widget.viewModel.ledger.movementById(
                                  row.movementId,
                                )!,
                              ),
                        child: const Text('Ver movimiento vinculado'),
                      ),
                      if (widget.viewModel.ledger
                          .movementById(row.movementId)!
                          .details
                          .reconciled)
                        const Text('Conciliada con movimiento bancario')
                      else
                        TextButton(
                          onPressed: busy ? null : () => reconcile(row),
                          child: Text('Conciliar cuota ${row.number}'),
                        ),
                    ],
                  ],
                  if (plan.state == InstallmentPlanState.active)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Cancelar cargos futuros'),
                                  content: const Text(
                                    'Se detienen las cuotas futuras. Los cargos ya generados se conservan; esto no registra un pago ni una liquidación bancaria.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Volver'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Cancelar plan'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await widget.viewModel.cancel();
                              }
                            },
                      child: const Text('Cancelar cargos futuros'),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
