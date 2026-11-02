import 'package:flutter/material.dart';

import '../../domain/models/money.dart';
import '../../domain/models/movement.dart';
import 'movement_labels.dart';
import 'movements_view_model.dart';

class MovementFilters extends StatefulWidget {
  const MovementFilters({super.key, required this.viewModel});
  final MovementsViewModel viewModel;
  @override
  State<MovementFilters> createState() => _MovementFiltersState();
}

class _MovementFiltersState extends State<MovementFilters> {
  late final TextEditingController _search;
  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.viewModel.search);
  }

  @override
  void didUpdateWidget(covariant MovementFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_search.text != widget.viewModel.search) {
      _search.text = widget.viewModel.search;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _chooseDates() async {
    final vm = widget.viewModel;
    final filter = vm.filter;
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: vm.today,
      initialDateRange: filter.from == null || filter.to == null
          ? null
          : DateTimeRange(start: filter.from!, end: filter.to!),
      helpText: 'Filtrar por fechas',
    );
    if (dates != null && mounted) vm.filterByDates(dates.start, dates.end);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final filter = vm.filter;
    String formatDate(DateTime date) =>
        MaterialLocalizations.of(context).formatCompactDate(date);
    final dates = switch ((filter.from, filter.to)) {
      (null, null) => 'Todas las fechas',
      (final from?, null) => 'Desde ${formatDate(from)}',
      (null, final to?) => 'Hasta ${formatDate(to)}',
      (final from?, final to?) => '${formatDate(from)} – ${formatDate(to)}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: vm.searchFor,
          decoration: const InputDecoration(
            labelText: 'Buscar en descripción',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 640
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('history-account-${filter.accountId}'),
                    initialValue: filter.accountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por cuenta',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          'Todas las cuentas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final account in vm.accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            '${account.details.name} · ${account.details.openingBalance.currency.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: vm.filterByAccount,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<MovementType>(
                    key: ValueKey('history-type-${filter.type}'),
                    initialValue: filter.type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por operación',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<MovementType>(
                        value: null,
                        child: Text(
                          'Todas las operaciones',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final type in MovementType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: vm.filterByType,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<Currency>(
                    key: ValueKey('history-currency-${filter.currency}'),
                    initialValue: filter.currency,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por moneda',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<Currency>(
                        value: null,
                        child: Text(
                          'Todas las monedas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final currency in Currency.values)
                        DropdownMenuItem(
                          value: currency,
                          child: Text(currency.code),
                        ),
                    ],
                    onChanged: vm.filterByCurrency,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _chooseDates,
              icon: const Icon(Icons.date_range),
              label: Text(dates),
            ),
            if (filter.isActive)
              TextButton(
                onPressed: () {
                  _search.clear();
                  vm.clearFilters();
                },
                child: const Text('Limpiar filtros'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${vm.visibleMovements.length} de ${vm.movements.length} movimientos',
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
