import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import '../../domain/models/account.dart';
import '../../domain/models/account_activity.dart';
import '../../domain/models/money.dart';
import '../core/page_content.dart';
import '../core/date_input.dart';
import '../accounts/account_labels.dart';
import 'movement_labels.dart';
import 'movements_view_model.dart';

class CreateMovementView extends StatefulWidget {
  const CreateMovementView({
    super.key,
    required this.viewModel,
    this.target,
    this.initialType,
  });
  final MovementsViewModel viewModel;
  final AccountDetailTarget? target;
  final MovementType? initialType;
  @override
  State<CreateMovementView> createState() => _CreateMovementViewState();
}

class _CreateMovementViewState extends State<CreateMovementView> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _dateInput = TextEditingController();
  MovementType _type = MovementType.expense;
  int? _accountId;
  int? _counterpartyId;
  int? _debitCardId;
  int? _categoryId;
  Currency? _currency;
  PaymentFunding _paymentFunding = PaymentFunding.account;
  @override
  void initState() {
    super.initState();
    _dateInput.text = DateInput.format(widget.viewModel.today);
    _selectOperation(widget.initialType ?? _type);
  }

  void _selectOperation(MovementType type) {
    final funding =
        type == MovementType.creditPayment &&
            widget.viewModel.originsFor(type, target: widget.target).isEmpty
        ? PaymentFunding.externalCash
        : PaymentFunding.account;
    _setPaymentFunding(type, funding);
    _categoryId = null;
  }

  void _setPaymentFunding(MovementType type, PaymentFunding funding) {
    final defaults = widget.viewModel.defaultsFor(
      type,
      widget.target,
      paymentFunding: funding,
    );
    _type = type;
    _paymentFunding = funding;
    _accountId = defaults.accountId;
    _counterpartyId = defaults.counterpartyId;
    _debitCardId = defaults.debitCardId;
    _currency = defaults.currency;
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _dateInput.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await widget.viewModel.createMovement(
      type: _type,
      accountId: _accountId,
      counterpartyAccountId: _counterpartyId,
      debitCardId: _debitCardId,
      categoryId: _categoryId,
      currency: _currency,
      amount: _amount.text,
      description: _description.text,
      dateInput: _dateInput.text,
      target: widget.target,
      paymentFunding: _paymentFunding,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final typed = DateInput.tryParse(_dateInput.text);
    final date = await showDatePicker(
      context: context,
      initialDate: typed != null && !typed.isAfter(widget.viewModel.today)
          ? typed
          : widget.viewModel.today,
      firstDate: DateTime(1900),
      lastDate: widget.viewModel.today,
      helpText: 'Fecha del movimiento',
    );
    if (date != null && mounted) {
      _dateInput.text = DateInput.format(date);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final contextAccount = vm.contextAccountFor(widget.target);
      if (widget.target != null && contextAccount == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Nuevo movimiento')),
          body: const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Esta cuenta o tarjeta ya no está disponible.'),
            ),
          ),
        );
      }
      final externalCash =
          _type == MovementType.creditPayment &&
          _paymentFunding == PaymentFunding.externalCash;
      final defaults = vm.defaultsFor(
        _type,
        widget.target,
        paymentFunding: _paymentFunding,
      );
      final lockedOrigin = defaults.accountId != null;
      final lockedDestination = externalCash
          ? defaults.accountId != null
          : defaults.counterpartyId != null;
      final needsOther =
          _type == MovementType.transfer || _type == MovementType.creditPayment;
      final origins = vm.originsFor(_type, target: widget.target);
      final destinations = lockedDestination
          ? [contextAccount!]
          : externalCash
          ? vm.accounts
                .where(
                  (account) => account.details.type == AccountType.creditCard,
                )
                .toList()
          : vm.destinationsFor(_type, _accountId);
      final selectedAccount = vm.accountById(_accountId);
      final currencies =
          selectedAccount?.details.openingBalances
              .map((m) => m.currency)
              .toList() ??
          <Currency>[];
      final currency =
          _currency ?? selectedAccount?.details.openingBalance.currency;
      return PopScope(
        canPop: !vm.isSaving,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.initialType == null
                  ? 'Nuevo movimiento'
                  : 'Registrar ${_type.shortLabel.toLowerCase()}',
            ),
            automaticallyImplyLeading: !vm.isSaving,
          ),
          body: SafeArea(
            child: PageContent(
              children: [
                if (contextAccount != null) ...[
                  Text(
                    'Movimiento para: ${widget.target!.kind == AccountDetailKind.debitCard ? vm.debitCardById(widget.target!.id)!.details.name : contextAccount.identification}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                ],
                if (widget.initialType == null) ...[
                  DropdownButtonFormField<MovementType>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de operación',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final type in vm.operationsFor(widget.target))
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
                        : (type) => setState(() => _selectOperation(type!)),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_type == MovementType.creditPayment &&
                    (contextAccount == null ||
                        contextAccount.details.type ==
                            AccountType.creditCard)) ...[
                  DropdownButtonFormField<PaymentFunding>(
                    initialValue: _paymentFunding,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pago',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PaymentFunding.account,
                        child: Text('Desde una cuenta'),
                      ),
                      DropdownMenuItem(
                        value: PaymentFunding.externalCash,
                        child: Text('Efectivo en agencia'),
                      ),
                    ],
                    onChanged: vm.isSaving
                        ? null
                        : (funding) => setState(
                            () => _setPaymentFunding(_type, funding!),
                          ),
                  ),
                  if (externalCash) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Reduce la deuda de la tarjeta sin descontar una cuenta registrada.',
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
                if (!externalCash)
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
                            '${account.identification} · ${account.details.openingBalances.map((m) => m.currency.code).join(' / ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: vm.isSaving || lockedOrigin
                        ? null
                        : (id) => setState(() {
                            _accountId = id;
                            _counterpartyId = defaults.counterpartyId;
                            _debitCardId = null;
                            _currency = vm
                                .accountById(id)
                                ?.details
                                .openingBalance
                                .currency;
                          }),
                  ),
                if (currencies.length > 1) ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<Currency>(
                    key: ValueKey('currency-$_accountId'),
                    initialValue: currency,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Moneda del movimiento',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final value in currencies)
                        DropdownMenuItem(value: value, child: Text(value.code)),
                    ],
                    onChanged: vm.isSaving
                        ? null
                        : (value) => setState(() => _currency = value),
                  ),
                ],
                if (_type == MovementType.expense &&
                    vm.accountById(_accountId)?.details.type ==
                        AccountType.bank &&
                    vm.debitCardsFor(_accountId).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    key: ValueKey('debit-$_accountId'),
                    initialValue: _debitCardId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Tarjeta de débito (opcional)',
                      errorText: vm.fieldErrors['debitCard'],
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Sin tarjeta de débito'),
                      ),
                      for (final card in vm.debitCardsFor(_accountId))
                        DropdownMenuItem(
                          value: card.id,
                          child: Text(
                            '${card.details.name}${card.details.lastFour == null ? '' : ' · ${card.details.lastFour}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: vm.isSaving || defaults.debitCardId != null
                        ? null
                        : (id) => setState(() => _debitCardId = id),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El gasto se descuenta una sola vez de la cuenta bancaria seleccionada.',
                  ),
                ],
                if (!externalCash && origins.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Necesitas una cuenta de efectivo o bancaria para esta operación.',
                  ),
                ],
                if (needsOther) ...[
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'destination-${_type.name}-$_accountId-${_paymentFunding.name}',
                    ),
                    initialValue: externalCash ? _accountId : _counterpartyId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _type == MovementType.creditPayment
                          ? 'Tarjeta de destino'
                          : 'Cuenta de destino',
                      errorText:
                          vm.fieldErrors[externalCash
                              ? 'account'
                              : 'counterparty'],
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final account in destinations)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            account.identification,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged:
                        vm.isSaving ||
                            !externalCash && _accountId == null ||
                            lockedDestination
                        ? null
                        : (id) => setState(() {
                            if (externalCash) {
                              _accountId = id;
                              _currency = vm
                                  .accountById(id)
                                  ?.details
                                  .openingBalance
                                  .currency;
                            } else {
                              _counterpartyId = id;
                            }
                          }),
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
                if (_type == MovementType.expense ||
                    _type == MovementType.income ||
                    _type == MovementType.creditPayment) ...[
                  if (vm.categoriesFor(_type).isNotEmpty)
                    DropdownButtonFormField<int>(
                      key: ValueKey('movement-category-${_type.name}'),
                      initialValue: _categoryId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Categoría (opcional)',
                        errorText: vm.fieldErrors['category'],
                        errorMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Sin categoría'),
                        ),
                        for (final category in vm.categoriesFor(_type))
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              category.details.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: vm.isSaving
                          ? null
                          : (id) => setState(() => _categoryId = id),
                    )
                  else
                    const Text(
                      'Puedes crear categorías desde Movimientos → Categorías.',
                    ),
                  const SizedBox(height: 20),
                ],
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
                    errorText: vm.fieldErrors['amount'],
                    errorMaxLines: 4,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _dateInput,
                  enabled: !vm.isSaving,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Fecha del movimiento',
                    hintText: 'dd/mm/yyyy',
                    helperText: 'dd/mm/yyyy',
                    errorText: vm.fieldErrors['date'],
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Elegir fecha en el calendario',
                      onPressed: vm.isSaving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                    ),
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
