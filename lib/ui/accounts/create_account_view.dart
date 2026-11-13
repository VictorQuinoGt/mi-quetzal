import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/account.dart';
import '../../domain/models/money.dart';
import '../core/page_content.dart';
import 'account_labels.dart';
import 'accounts_view_model.dart';
import 'financial_institution_field.dart';

class CreateAccountView extends StatefulWidget {
  const CreateAccountView({super.key, required this.viewModel, this.account});
  final AccountsViewModel viewModel;
  final Account? account;

  @override
  State<CreateAccountView> createState() => _CreateAccountViewState();
}

class _CreateAccountViewState extends State<CreateAccountView> {
  static const _balanceHelp =
      'Hasta 2 decimales, sin separadores de miles. Escribe 0 si no hay saldo.';
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _limit = TextEditingController();
  final _lastFour = TextEditingController();
  final _secondaryBalance = TextEditingController();
  final _secondaryLimit = TextEditingController();
  BankAccountType? _bankAccountType = BankAccountType.monetary;
  AccountType _type = AccountType.bank;
  Currency _currency = Currency.gtq;
  int? _institutionId;
  DateTime? _closingDate;
  DateTime? _paymentDate;

  @override
  void initState() {
    super.initState();
    if (widget.account case final account?) {
      final details = account.details;
      _name.text = details.name;
      _institutionId = details.financialInstitutionId;
      _closingDate = details.nextClosingDate;
      _paymentDate = details.nextPaymentDueDate;
      _type = details.type;
      _currency = details.openingBalance.currency;
      _balance.text = details.openingBalance.input;
      _limit.text = details.creditLimit?.input ?? '';
      _lastFour.text = details.lastFour ?? '';
      _secondaryBalance.text = details.secondaryOpeningBalance?.input ?? '';
      _secondaryLimit.text = details.secondaryCreditLimit?.input ?? '';
      _bankAccountType = details.bankAccountType;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _balance,
      _limit,
      _lastFour,
      _secondaryBalance,
      _secondaryLimit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await widget.viewModel.saveAccount(
      editingId: widget.account?.id,
      nextClosingDate: _closingDate,
      nextPaymentDueDate: _paymentDate,
      financialInstitutionId: _institutionId,
      name: _name.text,
      type: _type,
      currency: _currency,
      openingBalance: _balance.text,
      openingDate:
          widget.account?.details.openingDate ?? widget.viewModel.today,
      creditLimit: _currency == Currency.usd
          ? widget.account?.details.creditLimit?.input ?? ''
          : _limit.text,
      lastFour: _lastFour.text,
      bankAccountType: _bankAccountType,
      secondaryOpeningBalance: _secondaryBalance.text,
      secondaryCreditLimit: _currency == Currency.gtq
          ? (_secondaryBalance.text.trim().isEmpty
                ? ''
                : widget.account?.details.secondaryCreditLimit?.input ?? '')
          : _secondaryLimit.text,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  Widget _creditDate(
    String label,
    DateTime? date,
    ValueChanged<DateTime?> changed,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.viewModel.isSaving
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: date ?? widget.viewModel.today,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(9999, 12, 31),
                        helpText: label,
                      );
                      if (selected != null && mounted) {
                        setState(() => changed(selected));
                      }
                    },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                date == null
                    ? 'Sin configurar'
                    : MaterialLocalizations.of(context).formatFullDate(date),
              ),
            ),
          ),
          if (date != null)
            IconButton(
              onPressed: widget.viewModel.isSaving
                  ? null
                  : () => setState(() => changed(null)),
              tooltip: 'Quitar $label',
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final credit = _type == AccountType.creditCard;
        final editing = widget.account != null;
        final otherCurrency = _currency == Currency.gtq
            ? Currency.usd
            : Currency.gtq;
        String debtLabel(Currency currency) =>
            'Deuda inicial ${currency == Currency.gtq ? 'QTZ' : 'USD'}';
        return PopScope(
          canPop: !vm.isSaving,
          child: Scaffold(
            appBar: AppBar(
              title: Text(editing ? 'Editar cuenta' : 'Nueva cuenta'),
              automaticallyImplyLeading: !vm.isSaving,
            ),
            body: SafeArea(
              child: PageContent(
                children: [
                  Text(
                    'Dale un nombre a tu cuenta',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Usa un alias. No ingreses números completos de cuentas o tarjetas.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _name,
                    enabled: !vm.isSaving,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Alias',
                      hintText: 'Ej. Cuenta de uso diario',
                      errorText: vm.fieldErrors['name'],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<AccountType>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de cuenta',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final type in AccountType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: vm.isSaving || editing
                        ? null
                        : (value) => setState(() => _type = value!),
                  ),
                  const SizedBox(height: 20),
                  if (_type == AccountType.bank) ...[
                    DropdownButtonFormField<BankAccountType>(
                      initialValue: _bankAccountType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de cuenta bancaria',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        if (editing && _bankAccountType == null)
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Sin especificar'),
                          ),
                        const DropdownMenuItem(
                          value: BankAccountType.monetary,
                          child: Text('Monetario'),
                        ),
                        const DropdownMenuItem(
                          value: BankAccountType.savings,
                          child: Text('Ahorro'),
                        ),
                      ],
                      onChanged: vm.isSaving
                          ? null
                          : (value) => setState(() => _bankAccountType = value),
                    ),
                    const SizedBox(height: 20),
                  ],
                  DropdownButtonFormField<Currency>(
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Moneda',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final currency in Currency.values)
                        DropdownMenuItem(
                          value: currency,
                          child: Text(
                            currency == Currency.gtq
                                ? 'GTQ · Quetzales'
                                : 'USD · Dólares',
                          ),
                        ),
                    ],
                    onChanged: vm.isSaving || editing
                        ? null
                        : (value) => setState(() => _currency = value!),
                  ),
                  if (_type != AccountType.cash) ...[
                    const SizedBox(height: 20),
                    FinancialInstitutionField(
                      viewModel: vm,
                      selectedId: _institutionId,
                      onChanged: (value) =>
                          setState(() => _institutionId = value),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (editing) ...[
                    const Text(
                      'Editas la apertura; el saldo actual se recalcula con todos los movimientos. El tipo y la moneda principal se conservan.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _balance,
                    enabled: !vm.isSaving,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                      signed: _type == AccountType.bank,
                    ),
                    decoration: InputDecoration(
                      labelText: credit
                          ? debtLabel(_currency)
                          : 'Saldo inicial',
                      prefixText: '${_currency.code} ',
                      hintText: '0.00',
                      helperText: _balanceHelp,
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      errorText: vm.fieldErrors['openingBalance'],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (credit) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _secondaryBalance,
                      enabled: !vm.isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: debtLabel(otherCurrency),
                        prefixText: '${otherCurrency.code} ',
                        hintText: '0.00',
                        helperText: _balanceHelp,
                        helperMaxLines: 3,
                        errorMaxLines: 3,
                        errorText: vm.fieldErrors['secondaryOpeningBalance'],
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'El saldo inicial no se registra como ingreso ni gasto.',
                  ),
                  if (vm.fieldErrors['openingDate'] case final String error)
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (credit) ...[
                    const SizedBox(height: 20),
                    _creditDate(
                      'Fecha corte',
                      _closingDate,
                      (value) => _closingDate = value,
                    ),
                    const SizedBox(height: 20),
                    _creditDate(
                      'Fecha pago',
                      _paymentDate,
                      (value) => _paymentDate = value,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _currency == Currency.gtq
                          ? _limit
                          : _secondaryLimit,
                      enabled: !vm.isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Límite de crédito (opcional)',
                        prefixText: '${Currency.gtq.code} ',
                        errorText:
                            vm.fieldErrors[_currency == Currency.gtq
                                ? 'creditLimit'
                                : 'secondaryCreditLimit'],
                        errorMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_type != AccountType.cash) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _lastFour,
                      enabled: !vm.isSaving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: _type == AccountType.bank
                            ? 'Terminación (últimos 4 dígitos)'
                            : 'Últimos 4 dígitos (opcional)',
                        helperText:
                            'Nunca ingreses el número completo, CVV o PIN.',
                        helperMaxLines: 2,
                        errorText: vm.fieldErrors['lastFour'],
                        errorMaxLines: 2,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
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
                    label: Text(vm.isSaving ? 'Guardando…' : 'Guardar cuenta'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
