import 'package:flutter/material.dart';

import '../../domain/models/category.dart';
import '../../domain/models/movement.dart';
import '../movements/movements_view_model.dart';
import 'category_labels.dart';

Future<int?> showAddCategory(
  BuildContext context,
  MovementsViewModel vm, {
  CategoryKind initialKind = CategoryKind.expense,
  bool fixedKind = false,
}) {
  vm.startAddCategory();
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AddCategoryDialog(
      viewModel: vm,
      initialKind: initialKind,
      fixedKind: fixedKind,
    ),
  );
}

class CategoryField extends StatelessWidget {
  const CategoryField({
    super.key,
    required this.viewModel,
    required this.type,
    required this.selectedId,
    required this.onChanged,
    this.onAdded,
    this.label = 'Categoría (opcional)',
    this.dropdownKey,
  });
  final MovementsViewModel viewModel;
  final MovementType type;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  final VoidCallback? onAdded;
  final String label;
  final Key? dropdownKey;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      KeyedSubtree(
        key: ValueKey('$type-$selectedId'),
        child: DropdownButtonFormField<int>(
          key: dropdownKey,
          initialValue: selectedId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            errorText: viewModel.fieldErrors['category'],
            errorMaxLines: 3,
          ),
          items: [
            const DropdownMenuItem<int>(
              value: null,
              child: Text('Sin categoría'),
            ),
            for (final category in viewModel.categoriesFor(type))
              DropdownMenuItem(
                value: category.id,
                child: Text(
                  category.details.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: viewModel.isSaving ? null : onChanged,
        ),
      ),
      TextButton.icon(
        onPressed: viewModel.isSaving
            ? null
            : () async {
                final kind = switch (type) {
                  MovementType.expense => CategoryKind.expense,
                  MovementType.income => CategoryKind.income,
                  MovementType.creditPayment => CategoryKind.payment,
                  _ => throw StateError('Operación sin categoría'),
                };
                final id = await showAddCategory(
                  context,
                  viewModel,
                  initialKind: kind,
                  fixedKind: true,
                );
                if (context.mounted && id != null) {
                  onChanged(id);
                  onAdded?.call();
                }
              },
        icon: const Icon(Icons.add),
        label: const Text('Agregar categoría'),
      ),
    ],
  );
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog({
    required this.viewModel,
    required this.initialKind,
    required this.fixedKind,
  });
  final MovementsViewModel viewModel;
  final CategoryKind initialKind;
  final bool fixedKind;
  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _name = TextEditingController();
  late CategoryKind _kind = widget.initialKind;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final category = await widget.viewModel.addCategory(
      name: _name.text,
      kind: _kind,
    );
    if (mounted && category != null) Navigator.of(context).pop(category.id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      return PopScope(
        canPop: !vm.isSaving,
        child: AlertDialog(
          title: const Text('Agregar categoría'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.fixedKind) ...[
                Text('Uso: ${_kind.label}'),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _name,
                autofocus: true,
                enabled: !vm.isSaving,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: vm.isSaving ? null : (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Nombre de categoría',
                  border: const OutlineInputBorder(),
                  errorText: vm.categoryNameError,
                  errorMaxLines: 3,
                ),
              ),
              if (!widget.fixedKind) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<CategoryKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Uso de la categoría',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final kind in CategoryKind.values)
                      DropdownMenuItem(value: kind, child: Text(kind.label)),
                  ],
                  onChanged: vm.isSaving
                      ? null
                      : (kind) => setState(() => _kind = kind!),
                ),
              ],
              if (vm.categorySaveError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    vm.categorySaveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: vm.isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: vm.isSaving ? null : _save,
              child: Text(vm.isSaving ? 'Guardando…' : 'Agregar'),
            ),
          ],
        ),
      );
    },
  );
}
