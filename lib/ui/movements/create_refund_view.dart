import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import '../../domain/models/money.dart';
import '../core/page_content.dart';
import 'movements_view_model.dart';

class CreateRefundView extends StatefulWidget {
  const CreateRefundView({
    super.key,
    required this.viewModel,
    required this.original,
  });
  final MovementsViewModel viewModel;
  final Movement original;

  @override
  State<CreateRefundView> createState() => _CreateRefundViewState();
}

class _CreateRefundViewState extends State<CreateRefundView> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.viewModel.today;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.original.details.date,
      lastDate: widget.viewModel.today,
      helpText: 'Fecha de la devolución',
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await widget.viewModel.refundPurchase(
      originalMovementId: widget.original.id,
      amount: _amount.text,
      description: _description.text,
      date: _date,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final original = widget.original;
      final remaining = vm.remainingRefund(original);
      return PopScope(
        canPop: !vm.isSaving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Nueva devolución'),
            automaticallyImplyLeading: !vm.isSaving,
          ),
          body: SafeArea(
            child: PageContent(
              children: [
                Text(
                  'Compra original',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(original.details.description),
                Text('Importe original: ${original.details.amount.formatted}'),
                Text(
                  'Cuenta: ${vm.accountById(original.details.accountId)!.details.name}',
                ),
                Text('Pendiente de devolver: ${remaining.formatted}'),
                const SizedBox(height: 16),
                const Text(
                  'Devuelve fondos o reduce la deuda en la misma cuenta. Reduce los gastos del mes de la devolución, sin sumar ingresos. Usa la categoría de la compra original.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _description,
                  enabled: !vm.isSaving,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Descripción de la devolución',
                    border: const OutlineInputBorder(),
                    errorMaxLines: 3,
                    errorText: vm.fieldErrors['description'],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amount,
                  enabled: !vm.isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Importe a devolver',
                    prefixText: '${remaining.currency.code} ',
                    helperText: 'Mayor que cero, hasta 2 decimales, sin separadores de miles.',
                    helperMaxLines: 3,
                    errorMaxLines: 4,
                    border: const OutlineInputBorder(),
                    errorText: vm.fieldErrors['amount'],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: vm.isSaving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    'Fecha: ${MaterialLocalizations.of(context).formatMediumDate(_date)}',
                  ),
                ),
                for (final field in ['date', 'originalMovement', 'account'])
                  if (vm.fieldErrors[field] case final String error)
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                const SizedBox(height: 24),
                if (vm.saveError case final String error) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: vm.isSaving ? null : _save,
                  icon: vm.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.undo),
                  label: Text(
                    vm.isSaving ? 'Guardando…' : 'Guardar devolución',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
