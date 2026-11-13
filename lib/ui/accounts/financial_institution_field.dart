import 'package:flutter/material.dart';

import 'accounts_view_model.dart';

class FinancialInstitutionField extends StatelessWidget {
  const FinancialInstitutionField({
    super.key,
    required this.viewModel,
    required this.selectedId,
    required this.onChanged,
    this.unspecifiedLabel = 'Sin especificar',
    this.dropdownKey,
  });

  final AccountsViewModel viewModel;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  final String unspecifiedLabel;
  final Key? dropdownKey;

  Future<void> _add(BuildContext context) async {
    viewModel.startCreateInstitution();
    final id = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateInstitutionDialog(viewModel: viewModel),
    );
    if (context.mounted && id != null) onChanged(id);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Actualiza el FormField al seleccionar la entidad creada en el diálogo.
      KeyedSubtree(
        key: ValueKey(selectedId),
        child: DropdownButtonFormField<int>(
          key: dropdownKey,
          initialValue: selectedId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Entidad financiera',
            border: const OutlineInputBorder(),
            errorText: viewModel.fieldErrors['financialInstitution'],
            errorMaxLines: 3,
            helperText: viewModel.financialInstitutions.isEmpty
                ? 'Aún no hay entidades financieras registradas.'
                : null,
            helperMaxLines: 2,
          ),
          items: [
            DropdownMenuItem<int>(value: null, child: Text(unspecifiedLabel)),
            for (final institution in viewModel.financialInstitutions)
              DropdownMenuItem(
                value: institution.id,
                child: Text(
                  institution.details.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: viewModel.isSaving ? null : onChanged,
        ),
      ),
      TextButton.icon(
        onPressed: viewModel.isSaving ? null : () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar entidad financiera'),
      ),
    ],
  );
}

class _CreateInstitutionDialog extends StatefulWidget {
  const _CreateInstitutionDialog({required this.viewModel});

  final AccountsViewModel viewModel;

  @override
  State<_CreateInstitutionDialog> createState() =>
      _CreateInstitutionDialogState();
}

class _CreateInstitutionDialogState extends State<_CreateInstitutionDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final institution = await widget.viewModel.createFinancialInstitution(
      _name.text,
    );
    if (mounted && institution != null) {
      Navigator.of(context).pop(institution.id);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      return PopScope(
        canPop: !vm.isSavingInstitution,
        child: AlertDialog(
          title: const Text('Agregar entidad financiera'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                enabled: !vm.isSavingInstitution,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: vm.isSavingInstitution ? null : (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Nombre de entidad financiera',
                  border: const OutlineInputBorder(),
                  errorText: vm.institutionNameError,
                  errorMaxLines: 3,
                ),
              ),
              if (vm.institutionSaveError case final error?)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: vm.isSavingInstitution
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: vm.isSavingInstitution ? null : _save,
              child: Text(
                vm.isSavingInstitution
                    ? 'Guardando entidad…'
                    : 'Guardar entidad',
              ),
            ),
          ],
        ),
      );
    },
  );
}
