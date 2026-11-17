import 'package:flutter/material.dart';

import '../../domain/models/category.dart';
import '../core/page_content.dart';
import '../movements/movements_view_model.dart';
import 'category_field.dart';
import 'category_labels.dart';

class CategoriesView extends StatefulWidget {
  const CategoriesView({super.key, required this.viewModel});
  final MovementsViewModel viewModel;
  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView> {
  CategoryKind? _filter;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final categories = vm.categories
          .where((c) => _filter == null || c.details.kind == _filter)
          .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Categorías')),
        body: SafeArea(
          child: PageContent(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: vm.isSaving
                      ? null
                      : () => showAddCategory(
                          context,
                          vm,
                          initialKind: _filter ?? CategoryKind.expense,
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar categoría'),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final kind in CategoryKind.values)
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: _filter == kind,
                      onSelected: (_) => setState(() => _filter = kind),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (categories.isEmpty)
                const Text('Aún no hay categorías para este uso.'),
              for (final category in categories)
                Card(
                  child: ListTile(
                    title: Text(category.details.name),
                    subtitle: Text(category.details.kind.label),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
