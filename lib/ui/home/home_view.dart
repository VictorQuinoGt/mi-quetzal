import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/navigation/app_section.dart';
import '../core/page_content.dart';
import '../movements/movements_view_model.dart';
import 'monthly_summary_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({
    super.key,
    required this.onNavigate,
    required this.viewModel,
  });

  final ValueChanged<AppSection> onNavigate;
  final MovementsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageContent(
      children: [
        Text('TU ESPACIO FINANCIERO', style: theme.textTheme.labelLarge),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.forest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.spa_outlined,
                color: Color(0xFFD5ECA4),
                size: 36,
              ),
              const SizedBox(height: 20),
              Text(
                'Tu dinero,\ncon claridad.',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Un lugar para organizar tus cuentas, entender tus gastos '
                'y dar forma a tus planes.',
                style: TextStyle(color: Color(0xFFE0EDE4), fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: () => onNavigate(AppSection.accounts),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Explorar mis cuentas'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        MonthlySummaryView(viewModel: viewModel),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Registra tus cuentas, compras, ingresos y pagos. '
                    'Consulta los saldos actualizados en Cuentas. '
                    'La planificación estará disponible próximamente.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('Todo tiene su lugar', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Conoce las secciones de tu nuevo espacio.'),
        const SizedBox(height: 20),
        _SectionCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Cuentas y tarjetas',
          description: 'Fondos disponibles y deuda, cada uno en su lugar.',
          onTap: () => onNavigate(AppSection.accounts),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.swap_vert_rounded,
          title: 'Tus movimientos',
          description: 'Compras, ingresos y pagos con un historial claro.',
          onTap: () => onNavigate(AppSection.movements),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.calendar_month_outlined,
          title: 'Planes que avanzan',
          description: 'Presupuestos, metas y próximos compromisos.',
          onTap: () => onNavigate(AppSection.planning),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(description),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
