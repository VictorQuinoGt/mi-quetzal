import 'package:flutter/material.dart';

import '../accounts/accounts_view_model.dart';
import '../accounts/financial_institution_field.dart';
import '../core/page_content.dart';

class FinancialInstitutionsView extends StatelessWidget {
  const FinancialInstitutionsView({super.key, required this.viewModel});
  final AccountsViewModel viewModel;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Entidades financieras')),
      body: SafeArea(
        child: PageContent(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: viewModel.isSaving
                    ? null
                    : () => showAddFinancialInstitution(context, viewModel),
                icon: const Icon(Icons.add),
                label: const Text('Agregar entidad financiera'),
              ),
            ),
            const SizedBox(height: 20),
            if (viewModel.financialInstitutions.isEmpty)
              const Text('Aún no hay entidades financieras.'),
            for (final institution in viewModel.financialInstitutions)
              Card(child: ListTile(title: Text(institution.details.name))),
          ],
        ),
      ),
    ),
  );
}
