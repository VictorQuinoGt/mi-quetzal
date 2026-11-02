import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/page_content.dart';
import 'accounts_view_model.dart';

class CreateDebitCardView extends StatefulWidget {
  const CreateDebitCardView({super.key, required this.viewModel});
  final AccountsViewModel viewModel;
  @override
  State<CreateDebitCardView> createState() => _CreateDebitCardViewState();
}

class _CreateDebitCardViewState extends State<CreateDebitCardView> {
  final _name = TextEditingController();
  final _lastFour = TextEditingController();
  int? _accountId;
  @override
  void dispose() {
    _name.dispose();
    _lastFour.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await widget.viewModel.createDebitCard(
      name: _name.text,
      accountId: _accountId,
      lastFour: _lastFour.text,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      return PopScope(
        canPop: !vm.isSaving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Vincular tarjeta de débito',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            automaticallyImplyLeading: !vm.isSaving,
          ),
          body: SafeArea(
            child: PageContent(
              children: [
                Text(
                  'Una tarjeta, la misma cuenta',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'La tarjeta usará el saldo y la moneda de su cuenta bancaria. Varias tarjetas pueden compartirla sin duplicar los fondos.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  enabled: !vm.isSaving,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Alias de tarjeta',
                    errorText: vm.fieldErrors['name'],
                    errorMaxLines: 3,
                    helperText: 'Usa un alias; no ingreses el número completo.',
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Cuenta bancaria',
                    errorText: vm.fieldErrors['account'],
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final account in vm.bankAccounts)
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
                      : (id) => setState(() => _accountId = id),
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
                    errorText: vm.fieldErrors['lastFour'],
                    errorMaxLines: 3,
                    helperText: 'Nunca ingreses el número completo, CVV o PIN.',
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
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
                      : const Icon(Icons.link),
                  label: Text(vm.isSaving ? 'Guardando…' : 'Vincular tarjeta'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
