import 'package:flutter/material.dart';

import '../../domain/models/movement.dart';
import '../core/page_content.dart';
import '../movements/movements_view_model.dart';
import 'category_field.dart';

class CategorizeMovementView extends StatefulWidget {
  const CategorizeMovementView({
    super.key,
    required this.viewModel,
    required this.movement,
    this.onCatalogChanged,
  });
  final MovementsViewModel viewModel;
  final Movement movement;
  final VoidCallback? onCatalogChanged;
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
                CategoryField(
                  viewModel: vm,
                  type: widget.movement.details.type,
                  selectedId: _categoryId,
                  label: 'Categoría',
                  onChanged: (id) => setState(() => _categoryId = id),
                  onAdded: widget.onCatalogChanged,
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
