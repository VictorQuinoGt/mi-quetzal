import 'package:flutter/material.dart';

import '../../domain/models/account.dart';
import 'account_detail_view_model.dart';

class CreditSummary extends StatelessWidget {
  const CreditSummary({
    super.key,
    required this.account,
    required this.viewModel,
  });
  final Account account;
  final AccountDetailViewModel viewModel;
  @override
  Widget build(BuildContext context) {
    Widget pair(Widget left, Widget right) => LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 12), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
    Widget cell(String label, List<String> values) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label.isNotEmpty)
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        for (final value in values)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              value,
              softWrap: false,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
      ],
    );
    final balances = account.currentBalances;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Deuda actual', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            if (balances.length == 2)
              pair(
                cell('', [
                  balances.first.minorUnits < 0
                      ? '${balances.first.absolute.compact} a favor'
                      : balances.first.compact,
                ]),
                cell('', [
                  balances.last.minorUnits < 0
                      ? '${balances.last.absolute.compact} a favor'
                      : balances.last.compact,
                ]),
              )
            else
              cell('', [
                balances.first.minorUnits < 0
                    ? '${balances.first.absolute.compact} a favor'
                    : balances.first.compact,
              ]),
            const Divider(height: 24),
            pair(
              cell('Fecha corte', [
                viewModel.shortDate(account.details.nextClosingDate),
              ]),
              cell('Fecha pago', [
                viewModel.shortDate(account.details.nextPaymentDueDate),
              ]),
            ),
            const SizedBox(height: 16),
            pair(
              cell('Límite', viewModel.limitLabels),
              cell('Disponible', viewModel.availableLabels),
            ),
            if (account.reservedCredit.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final amount in account.reservedCredit.values)
                Text('Reserva de capital pendiente: ${amount.compact}'),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Ayuda sobre deuda y período',
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Deuda, disponible y período'),
                    content: const SingleChildScrollView(
                      child: Text(
                        'La deuda incluye cargos ya registrados. El calendario de cuotas futuras es un compromiso aparte. Disponible resta deuda ordinaria y reservas de capital conocidas, por moneda. Si falta desglose o no se conoce la asignación de un pago entre líneas, se omite ese disponible. Los movimientos del período corresponden a meses calendario y no son el saldo final de ese mes. Corte y pago conservan sus fechas completas independientes.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
