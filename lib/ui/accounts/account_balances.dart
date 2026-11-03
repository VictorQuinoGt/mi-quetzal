import 'package:flutter/material.dart';

import '../../domain/models/account.dart';

class AccountBalances extends StatelessWidget {
  const AccountBalances({
    super.key,
    required this.account,
    required this.label,
  });
  final Account account;
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      for (final value in account.currentBalances)
        Text(
          account.details.type == AccountType.creditCard && value.minorUnits < 0
              ? '${value.absolute.formatted} a favor'
              : value.formatted,
          style: theme.textTheme.titleLarge,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            if (values.length == 2 &&
                constraints.maxWidth >= 280 &&
                MediaQuery.textScalerOf(context).scale(14) <= 18) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: values.first),
                  const SizedBox(width: 12),
                  Expanded(child: values.last),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  values[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
