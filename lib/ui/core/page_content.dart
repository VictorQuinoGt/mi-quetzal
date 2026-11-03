import 'package:flutter/material.dart';

/// Mantiene la lectura cómoda en escritorio y deja espacio para el botón flotante.
class PageContent extends StatelessWidget {
  const PageContent({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 112),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
