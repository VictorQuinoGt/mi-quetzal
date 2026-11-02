import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import '../core/page_content.dart';
import 'movement_labels.dart';
import 'movements_view_model.dart';

class CreateMovementView extends StatefulWidget {
  const CreateMovementView({super.key, required this.viewModel});
  final MovementsViewModel viewModel;
  @override
  State<CreateMovementView> createState() => _CreateMovementViewState();
}

class _CreateMovementViewState extends State<CreateMovementView> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  MovementType _type = MovementType.expense;
  int? _accountId;
  int? _counterpartyId;
  late DateTime _date;
  @override
  void initState() {
    super.initState();
    _date = widget.viewModel.today;
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await widget.viewModel.createMovement(
      type: _type,
      accountId: _accountId,
      counterpartyAccountId: _counterpartyId,
      amount: _amount.text,
      description: _description.text,
      date: _date,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: widget.viewModel.today,
      helpText: 'Fecha del movimiento',
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final needsOther =
          _type == MovementType.transfer || _type == MovementType.creditPayment;
      final origins = vm.originsFor(_type);
      final destinations = vm.destinationsFor(_type, _accountId);
      final currency = vm
          .accountById(_accountId)
          ?.details
          .openingBalance
          .currency;
      return PopScope(
        canPop: !vm.isSaving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Nuevo movimiento'),
            automaticallyImplyLeading: !vm.isSaving,
          ),
          body: SafeArea(
            child: PageContent(
              children: [
                DropdownButtonFormField<MovementType>(
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de operación',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final type in MovementType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: vm.isSaving
                      ? null
                      : (type) => setState(() {
                          _type = type!;
                          _accountId = null;
                          _counterpartyId = null;
                        }),
                ),
                const SizedBox(height: 16),
                Text(_type.explanation),
                const SizedBox(height: 24),
                DropdownButtonFormField<int>(
                  key: ValueKey('origin-${_type.name}'),
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _type == MovementType.income
                        ? 'Cuenta receptora'
                        : _type == MovementType.expense
                        ? 'Cuenta o tarjeta'
                        : 'Cuenta de origen',
                    errorText: vm.fieldErrors['account'],
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final account in origins)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.details.name} · ${account.details.openingBalance.currency.name.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: vm.isSaving
                      ? null
                      : (id) => setState(() {
                          _accountId = id;
                          _counterpartyId = null;
                        }),
                ),
                if (origins.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Necesitas una cuenta de efectivo o bancaria para esta operación.',
                  ),
                ],
                if (needsOther) ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    key: ValueKey('destination-${_type.name}-$_accountId'),
                    initialValue: _counterpartyId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _type == MovementType.creditPayment
                          ? 'Tarjeta de destino'
                          : 'Cuenta de destino',
                      errorText: vm.fieldErrors['counterparty'],
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final account in destinations)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            account.details.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: vm.isSaving || _accountId == null
                        ? null
                        : (id) => setState(() => _counterpartyId = id),
                  ),
                  if (_accountId != null && destinations.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'No hay destinos compatibles. Agrega una cuenta del tipo necesario y de la misma moneda.',
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _description,
                  enabled: !vm.isSaving,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    errorText: vm.fieldErrors['description'],
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
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
                    labelText: 'Importe',
                    prefixText: currency == null
                        ? null
                        : '${currency.name.toUpperCase()} ',
                    helperText: 'Mayor que cero, hasta 2 decimales, sin separadores de miles.',
                    helperMaxLines: 3,
                    errorText: vm.fieldErrors['amount'],
                    errorMaxLines: 4,
                    border: const OutlineInputBorder(),
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
                if (vm.fieldErrors['date'] case final String error)
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
                      : const Icon(Icons.check),
                  label: Text(
                    vm.isSaving ? 'Guardando…' : 'Guardar movimiento',
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
