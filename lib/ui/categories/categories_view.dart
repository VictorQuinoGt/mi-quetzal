import 'package:flutter/material.dart';

import '../../domain/models/category.dart';
import '../core/page_content.dart';
import '../movements/movements_view_model.dart';
import 'category_labels.dart';

class CategoriesView extends StatefulWidget {
  const CategoriesView({super.key, required this.viewModel});
  final MovementsViewModel viewModel;
  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  final _name = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    final saved = await widget.viewModel.createCategory(
      name: _name.text,
      kind: _kind,
    );
    if (saved && mounted) {
      _name.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Categoría creada')));
    }
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
            title: const Text('Categorías'),
            automaticallyImplyLeading: !vm.isSaving,
          ),
          body: SafeArea(
            child: PageContent(
              children: [
                Text(
                  'Organiza tus ingresos y gastos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Crea tus propias categorías. Los movimientos anteriores permanecen sin categoría hasta que los clasifiques.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  enabled: !vm.isSaving,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nombre de categoría',
                    errorText: vm.fieldErrors['name'],
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
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
                  onPressed: vm.isSaving ? null : _create,
                  icon: vm.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(vm.isSaving ? 'Guardando…' : 'Crear categoría'),
                ),
                const SizedBox(height: 28),
                Text(
                  'Tus categorías',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (vm.categories.isEmpty)
                  const Text('Aún no hay categorías.')
                else
                  for (final category in vm.categories) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.details.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(category.details.kind.label),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
