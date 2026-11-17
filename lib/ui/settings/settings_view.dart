import 'package:flutter/material.dart';

import '../../app/appearance_view_model.dart';
import '../../domain/models/app_appearance.dart';
import '../core/page_content.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.appearance,
    required this.onCategories,
    required this.onInstitutions,
    required this.canManage,
  });
  final AppearanceViewModel appearance;
  final VoidCallback onCategories;
  final VoidCallback onInstitutions;
  final bool canManage;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appearance,
    builder: (context, _) => PageContent(
      children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Categorías'),
                subtitle: const Text('Gastos, pagos e ingresos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: canManage ? onCategories : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: const Text('Entidades financieras'),
                trailing: const Icon(Icons.chevron_right),
                onTap: canManage ? onInstitutions : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        DropdownButtonFormField<AppAppearance>(
          key: ValueKey(appearance.appearance),
          initialValue: appearance.appearance,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tema de la app',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final value in AppAppearance.values)
              DropdownMenuItem(
                value: value,
                child: Text(switch (value) {
                  AppAppearance.system => 'Sistema',
                  AppAppearance.light => 'Claro',
                  AppAppearance.dark => 'Oscuro',
                }),
              ),
          ],
          onChanged: appearance.isSaving
              ? null
              : (value) => appearance.select(value!),
        ),
        if (appearance.error != null)
          Text(
            appearance.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
