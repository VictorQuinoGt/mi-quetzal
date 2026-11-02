import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/repositories/account_repository.dart';
import '../data/repositories/movement_repository.dart';

import 'app_theme.dart';
import 'navigation/app_shell.dart';

class MiQuetzalApp extends StatelessWidget {
  const MiQuetzalApp({
    super.key,
    required this.accountRepository,
    required this.movementRepository,
  });
  final AccountRepository accountRepository;
  final MovementRepository movementRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Quetzal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('es', 'GT'),
      supportedLocales: const [Locale('es', 'GT')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppShell(
        accountRepository: accountRepository,
        movementRepository: movementRepository,
      ),
    );
  }
}
