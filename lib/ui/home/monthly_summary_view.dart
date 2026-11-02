import 'package:flutter/material.dart';

import '../../domain/models/monthly_summary.dart';
import '../../domain/models/money.dart';
import '../movements/movements_view_model.dart';

class MonthlySummaryView extends StatelessWidget {
  const MonthlySummaryView({super.key, required this.viewModel});
  final MovementsViewModel viewModel;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final vm = viewModel;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Resumen mensual',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: vm.canGoToPreviousMonth
                    ? vm.previousSummaryMonth
                    : null,
                tooltip: 'Mes anterior',
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  MaterialLocalizations.of(context)
                      .formatMonthYear(vm.summaryMonth),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: vm.canGoToNextMonth ? vm.nextSummaryMonth : null,
                tooltip: 'Mes siguiente',
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (vm.status == MovementsStatus.loading)
            const Center(child: CircularProgressIndicator())
          else if (vm.status == MovementsStatus.error) ...[
            const Text('No se pudo cargar el resumen mensual.'),
            OutlinedButton.icon(
              onPressed: vm.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ] else if (vm.summaryError case final String error)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (vm.summary?.currencies.isEmpty ?? true)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sin ingresos ni gastos en este mes.'),
              ),
            )
          else
            for (final summary in vm.summary!.currencies) ...[
              _CurrencySummary(summary: summary),
              const SizedBox(height: 16),
            ],
          const SizedBox(height: 12),
          const Text(
            'Ingresos y gastos registrados del mes. Las devoluciones reducen los gastos en la fecha de devolución y pueden dejar gastos netos negativos. No incluyen saldos iniciales, transferencias ni pagos de tarjeta. La diferencia del mes no es el saldo disponible.',
          ),
        ],
      );
    },
  );
}

class _CurrencySummary extends StatelessWidget {
  const _CurrencySummary({required this.summary});
  final CurrencyMonthlySummary summary;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget amount(String label, Money value) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value.formatted, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
    Widget groups(String label, List<CategoryTotal> values) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(value.name), Text(value.amount.formatted)],
            ),
          ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(summary.currency.code, style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            amount('Ingresos del mes', summary.income),
            amount('Gastos del mes', summary.expense),
            amount('Diferencia del mes', summary.difference),
            if (summary.expenseByCategory.isNotEmpty)
              groups('Gastos por categoría', summary.expenseByCategory),
            if (summary.incomeByCategory.isNotEmpty)
              groups('Ingresos por categoría', summary.incomeByCategory),
          ],
        ),
      ),
    );
  }
}
