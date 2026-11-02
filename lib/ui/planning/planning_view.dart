import 'package:flutter/material.dart';

import '../core/feature_introduction.dart';

class PlanningView extends StatelessWidget {
  const PlanningView({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeatureIntroduction(
      title: 'Tu planificación',
      subtitle: 'Dale una dirección a tu dinero.',
      icon: Icons.calendar_month_outlined,
      emptyTitle: 'Haz espacio para tus próximos planes',
      description:
          'Los presupuestos, metas y compromisos llegarán en una próxima '
          'versión. Aquí podrás organizar lo que viene.',
      details: [
        (
          icon: Icons.pie_chart_outline,
          title: 'Presupuestos',
          description: 'Define cuánto quieres destinar a cada categoría.',
        ),
        (
          icon: Icons.flag_outlined,
          title: 'Metas de ahorro',
          description: 'Organiza tus objetivos y sigue su avance.',
        ),
        (
          icon: Icons.event_repeat_outlined,
          title: 'Compromisos recurrentes',
          description:
              'Anticipa próximos pagos. Un compromiso previsto todavía '
              'no es un gasto pagado.',
        ),
      ],
    );
  }
}
