import 'package:flutter/material.dart';

import '../../domain/models/installment_plan.dart';
import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import '../core/page_content.dart';
import 'installment_form_view_model.dart';

class InstallmentFormView extends StatefulWidget {
  const InstallmentFormView({super.key, required this.viewModel});
  final InstallmentFormViewModel viewModel;
  @override
  State<InstallmentFormView> createState() => _InstallmentFormViewState();
}

class _InstallmentFormViewState extends State<InstallmentFormView> {
  final fields = {
    for (final key in [
      'description',
      'original',
      'count',
      'monthly',
      'day',
      'previous',
      'principal',
      'interest',
      'fee',
    ])
      key: TextEditingController(),
  };
  late Currency currency;
  late DateTime firstDate;
  late DateTime reference;
  InstallmentCostMode costMode = InstallmentCostMode.noInterest;
  InstallmentLimitMode limitMode = InstallmentLimitMode.ordinary;
  int? categoryId;
  int? originalId;
  @override
  void initState() {
    super.initState();
    final vm = widget.viewModel;
    final plan = vm.editing;
    currency =
        plan?.draft.originalAmount.currency ??
        vm.ledger.accountById(vm.accountId)!.currentBalance.currency;
    firstDate = plan?.nextDate ?? vm.ledger.today;
    reference = vm.ledger.today;
    fields['day']!.text = '${firstDate.day}';
    fields['previous']!.text = '0';
    if (plan != null) {
      fields['description']!.text = plan.draft.description;
      fields['original']!.text = plan.draft.originalAmount.input;
      fields['count']!.text = '${plan.draft.count}';
      final row = plan.pending.first;
      fields['monthly']!.text = row.amount.input;
      fields['principal']!.text = row.principal?.input ?? '';
      fields['interest']!.text = row.interest?.input ?? '';
      fields['fee']!.text = row.fee?.input ?? '';
      costMode = plan.draft.costMode;
      limitMode = plan.draft.limitMode;
      categoryId = plan.draft.categoryId;
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  bool prepare() => widget.viewModel.prepare(
    description: fields['description']!.text,
    currency: currency,
    original: fields['original']!.text,
    count: fields['count']!.text,
    monthly: fields['monthly']!.text,
    firstDate: firstDate,
    day: fields['day']!.text,
    previous: fields['previous']!.text,
    reference: reference,
    costMode: costMode,
    limitMode: limitMode,
    principal: fields['principal']!.text,
    interest: fields['interest']!.text,
    fee: fields['fee']!.text,
    categoryId: categoryId,
    originalMovementId: originalId,
  );
  Future<void> pick(bool isFirst) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isFirst ? firstDate : reference,
      firstDate: DateTime(1900),
      lastDate: isFirst ? DateTime(9900) : widget.viewModel.ledger.today,
    );
    if (date != null && mounted) {
      setState(() {
        widget.viewModel.preview = null;
        if (isFirst) {
          firstDate = date;
          fields['day']!.text = '${date.day}';
        } else {
          reference = date;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final editing = vm.editing != null;
      Widget input(String key, String label, {bool numeric = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: fields[key],
          enabled: !vm.saving,
          maxLength: key == 'description' ? 100 : null,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          onChanged: (_) => setState(() => vm.preview = null),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
      return PopScope(
        canPop: !vm.saving,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              editing ? 'Editar cuotas pendientes' : 'Compra en cuotas',
            ),
            automaticallyImplyLeading: !vm.saving,
          ),
          body: SafeArea(
            child: PageContent(
              children: [
                Text(
                  'Tarjeta: ${vm.ledger.accountById(vm.accountId)!.details.name}',
                ),
                const SizedBox(height: 12),
                input('description', 'Descripción o comercio', numeric: false),
                DropdownButtonFormField<int>(
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Sin categoría'),
                    ),
                    for (final category in vm.ledger.categoriesFor(
                      MovementType.expense,
                    ))
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.details.name),
                      ),
                  ],
                  onChanged: vm.saving
                      ? null
                      : (id) => setState(() {
                          categoryId = id;
                          vm.preview = null;
                        }),
                ),
                const SizedBox(height: 16),
                if (!editing) ...[
                  DropdownButtonFormField<Currency>(
                    initialValue: currency,
                    decoration: const InputDecoration(
                      labelText: 'Moneda',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final balance
                          in vm.ledger
                              .accountById(vm.accountId)!
                              .currentBalances)
                        DropdownMenuItem(
                          value: balance.currency,
                          child: Text(balance.currency.code),
                        ),
                    ],
                    onChanged: vm.saving
                        ? null
                        : (value) => setState(() {
                            currency = value!;
                            originalId = null;
                            vm.preview = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  input('original', 'Monto original'),
                  input('count', 'Número total de cuotas'),
                ],
                input('monthly', 'Importe mensual real'),
                if (!editing) ...[
                  DropdownButtonFormField<InstallmentCostMode>(
                    initialValue: costMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Desglose de costos',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: InstallmentCostMode.noInterest,
                        child: Text('Sin intereses'),
                      ),
                      DropdownMenuItem(
                        value: InstallmentCostMode.fixedBreakdown,
                        child: Text(
                          'Capital, interés y comisión fijos conocidos',
                        ),
                      ),
                      DropdownMenuItem(
                        value: InstallmentCostMode.unknown,
                        child: Text('Desglose no informado'),
                      ),
                    ],
                    onChanged: vm.saving
                        ? null
                        : (value) => setState(() {
                            costMode = value!;
                            vm.preview = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                ],
                if (costMode == InstallmentCostMode.fixedBreakdown) ...[
                  input('principal', 'Capital mensual conocido'),
                  input('interest', 'Interés fijo por cuota (0 si no aplica)'),
                  input('fee', 'Comisión fija por cuota (0 si no aplica)'),
                ],
                if (costMode == InstallmentCostMode.unknown)
                  const Text(
                    'No se calcula amortización ni tasa. Si afecta el límite, el disponible se omite mientras falte el capital pendiente.',
                  ),
                OutlinedButton.icon(
                  onPressed: vm.saving ? null : () => pick(true),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    '${editing ? 'Siguiente fecha pendiente' : 'Primera fecha de cargo'}: ${MaterialLocalizations.of(context).formatMediumDate(firstDate)}',
                  ),
                ),
                const SizedBox(height: 16),
                input('day', 'Día mensual de cargo'),
                const Text(
                  'Se usan meses calendario. Si el día no existe, se utiliza el último día de ese mes. La última cuota ajusta el capital restante; no se estiman tasas.',
                ),
                if (!editing) ...[
                  const SizedBox(height: 16),
                  input('previous', 'Cuotas previamente cargadas'),
                  OutlinedButton(
                    onPressed: vm.saving ? null : () => pick(false),
                    child: Text(
                      'Fecha de referencia: ${MaterialLocalizations.of(context).formatMediumDate(reference)}',
                    ),
                  ),
                  const Text(
                    'Las cuotas previas ya están reflejadas en tu situación inicial: no se recrean ni se consideran pagadas. La siguiente pendiente debe quedar después de la referencia.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<InstallmentLimitMode>(
                    initialValue: limitMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Modalidad de límite',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: InstallmentLimitMode.ordinary,
                        child: Text('Utiliza el límite de la tarjeta'),
                      ),
                      DropdownMenuItem(
                        value: InstallmentLimitMode.additional,
                        child: Text('Línea adicional'),
                      ),
                    ],
                    onChanged: vm.saving
                        ? null
                        : (value) => setState(() {
                            limitMode = value!;
                            vm.preview = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey('original-$currency'),
                    initialValue: originalId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Compra completa ya registrada (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Sin compra completa previa'),
                      ),
                      for (final movement in vm.eligibleOriginals(currency))
                        DropdownMenuItem(
                          value: movement.id,
                          child: Text(
                            '${movement.details.description} · ${movement.details.amount.compact}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: vm.saving
                        ? null
                        : (id) => setState(() {
                            originalId = id;
                            vm.preview = null;
                          }),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Si vinculas una compra completa, su gasto se conserva. Se reclasifica la deuda aún no cargada y las cuotas no vuelven a reconocer ese capital como gasto.',
                  ),
                ],
                const SizedBox(height: 20),
                if (vm.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      vm.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                OutlinedButton(
                  onPressed: vm.saving ? null : prepare,
                  child: const Text('Ver calendario antes de guardar'),
                ),
                if (vm.preview != null) ...[
                  const SizedBox(height: 16),
                  const Text('Calendario propuesto'),
                  for (final row in vm.previewRows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${editing ? vm.editing!.pending[row.number - 1].number : row.number}. ${MaterialLocalizations.of(context).formatMediumDate(row.date)} · ${row.amount.compact}${row.previouslyLoaded ? ' · Previamente cargada' : ''}${row.principal == null ? ' · Capital no informado' : ' · Capital ${row.principal!.compact} / interés ${row.interest!.compact} / comisión ${row.fee!.compact}'}',
                      ),
                    ),
                  FilledButton(
                    onPressed: vm.saving
                        ? null
                        : () async {
                            if (await vm.save() && context.mounted) {
                              Navigator.pop(context, true);
                            }
                          },
                    child: Text(
                      vm.saving ? 'Guardando…' : 'Guardar plan y calendario',
                    ),
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
