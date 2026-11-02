import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/account.dart';
import '../../domain/models/money.dart';
import '../core/page_content.dart';
import 'account_labels.dart';
import 'accounts_view_model.dart';

class CreateAccountView extends StatefulWidget {
  const CreateAccountView({super.key, required this.viewModel});
  final AccountsViewModel viewModel;

  @override
  State<CreateAccountView> createState() => _CreateAccountViewState();
}

class _CreateAccountViewState extends State<CreateAccountView> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _limit = TextEditingController();
  final _lastFour = TextEditingController();
  AccountType _type = AccountType.bank;
  Currency _currency = Currency.gtq;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.viewModel.today;
  }

  @override
  void dispose() {
    for (final controller in [_name, _balance, _limit, _lastFour]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await widget.viewModel.createAccount(
      name: _name.text,
      type: _type,
      currency: _currency,
      openingBalance: _balance.text,
      openingDate: _date,
      creditLimit: _limit.text,
      lastFour: _lastFour.text,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: widget.viewModel.today,
      helpText: 'Fecha del saldo inicial',
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final credit = _type == AccountType.creditCard;
        return PopScope(
          canPop: !vm.isSaving,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Nueva cuenta'),
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
                    onChanged: vm.isSaving
                        ? null
                        : (value) => setState(() => _type = value!),
                  ),
                  const SizedBox(height: 20),
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
                    onChanged: vm.isSaving
                        ? null
                        : (value) => setState(() => _currency = value!),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _balance,
                    enabled: !vm.isSaving,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                      signed: _type == AccountType.bank,
                    ),
                    decoration: InputDecoration(
                      labelText: credit ? 'Deuda inicial' : 'Saldo inicial',
                      prefixText: '${_currency.code} ',
                      hintText: '0.00',
                      helperText: 'Hasta 2 decimales, sin separadores de miles. Escribe 0 si no hay saldo.',
                      helperMaxLines: 3,
                      errorMaxLines: 3,
                      errorText: vm.fieldErrors['openingBalance'],
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'El saldo inicial indica lo que tenías en esta fecha; no se registra como ingreso ni gasto.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: vm.isSaving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Fecha: ${MaterialLocalizations.of(context).formatMediumDate(_date)}',
                    ),
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
                    TextField(
                      controller: _limit,
                      enabled: !vm.isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Límite de crédito (opcional)',
                        prefixText: '${_currency.code} ',
                        errorText: vm.fieldErrors['creditLimit'],
                        errorMaxLines: 3,
                        border: const OutlineInputBorder(),
                      ),
                    ),
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
                        labelText: 'Últimos 4 dígitos (opcional)',
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
