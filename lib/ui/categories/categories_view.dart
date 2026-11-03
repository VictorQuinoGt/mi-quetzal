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
  final _institutionName = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;
  bool _institutionForm = false;
  @override
  void dispose() {
    _name.dispose();
    _institutionName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _institutionForm = false);
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

  Future<void> _createInstitution() async {
    setState(() => _institutionForm = true);
    FocusScope.of(context).unfocus();
    final saved = await widget.viewModel.createFinancialInstitution(
      _institutionName.text,
    );
    if (saved && mounted) {
      _institutionName.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entidad financiera creada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final categoryError = _institutionForm ? null : vm.saveError;
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
                if (categoryError case final String error) ...[
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
                const SizedBox(height: 28),
                Text(
                  'Entidades financieras',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Crea el catálogo para identificar tus cuentas y tarjetas. Después selecciona la entidad al crear o editar una cuenta o tarjeta.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _institutionName,
                  enabled: !vm.isSaving,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre de entidad financiera',
                    errorText: vm.fieldErrors['institutionName'],
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_institutionForm && vm.saveError != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      vm.saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: vm.isSaving ? null : _createInstitution,
                  icon: vm.isSaving && _institutionForm
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_balance_outlined),
                  label: Text(
                    vm.isSaving && _institutionForm
                        ? 'Guardando entidad…'
                        : 'Agregar entidad financiera',
                  ),
                ),
                const SizedBox(height: 20),
                if (vm.financialInstitutions.isEmpty)
                  const Text('Aún no hay entidades financieras.')
                else
                  for (final institution in vm.financialInstitutions) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(institution.details.name),
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
