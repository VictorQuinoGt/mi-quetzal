import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import '../core/page_content.dart';
import '../movements/movements_view_model.dart';

class CategorizeMovementView extends StatefulWidget {
  const CategorizeMovementView({
    super.key,
    required this.viewModel,
    required this.movement,
  });
  final MovementsViewModel viewModel;
  final Movement movement;
  @override
  State<CategorizeMovementView> createState() => _CategorizeMovementViewState();
}

class _CategorizeMovementViewState extends State<CategorizeMovementView> {
  int? _categoryId;
  @override
  void initState() {
    super.initState();
    _categoryId = widget.movement.details.categoryId;
  }

  Future<void> _save() async {
    final saved = await widget.viewModel.assignCategory(
      widget.movement.id,
      _categoryId,
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
              'Categorizar movimiento',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            automaticallyImplyLeading: !vm.isSaving,
          ),
          body: SafeArea(
            child: PageContent(
              children: [
                Text(
                  widget.movement.details.description,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(widget.movement.details.amount.formatted),
                const SizedBox(height: 16),
                const Text(
                  'Solo cambia la categoría. La fecha, descripción, importe y saldos se conservan.',
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Categoría',
                    errorText: vm.fieldErrors['category'],
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Sin categoría'),
                    ),
                    for (final category in vm.categoriesFor(
                      widget.movement.details.type,
                    ))
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
                ),
                const SizedBox(height: 24),
                if (vm.fieldErrors['movement'] case final String error)
                  Text(error),
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
                  const SizedBox(height: 12),
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
                  label: Text(vm.isSaving ? 'Guardando…' : 'Guardar categoría'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
