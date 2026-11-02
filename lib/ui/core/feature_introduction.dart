import 'package:flutter/material.dart';

import 'page_content.dart';

class FeatureIntroduction extends StatelessWidget {
  const FeatureIntroduction({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.emptyTitle,
    required this.description,
    required this.details,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String emptyTitle;
  final String description;
  final List<({IconData icon, String title, String description})> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PageContent(
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(icon, color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(height: 24),
                Text(emptyTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 20),
                const Chip(
                  avatar: Icon(Icons.schedule_outlined, size: 18),
                  label: Text('Próximamente'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Qué podrás hacer', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final detail in details)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(detail.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(detail.title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(detail.description),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
