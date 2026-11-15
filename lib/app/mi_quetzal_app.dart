import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/repositories/account_repository.dart';
import '../data/repositories/movement_repository.dart';
import '../data/repositories/installment_repository.dart';

import 'app_theme.dart';
import 'appearance_view_model.dart';
import 'navigation/app_shell.dart';

class MiQuetzalApp extends StatelessWidget {
  const MiQuetzalApp({
    super.key,
    required this.accountRepository,
    required this.movementRepository,
    required this.installmentRepository,
    required this.appearanceViewModel,
    this.enableInstallmentPolling = false,
  });
  final AccountRepository accountRepository;
  final MovementRepository movementRepository;
  final InstallmentRepository installmentRepository;
  final AppearanceViewModel appearanceViewModel;
  final bool enableInstallmentPolling;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appearanceViewModel,
      builder: (context, _) => MaterialApp(
        title: 'Mi Quetzal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: appearanceViewModel.themeMode,
        locale: const Locale('es', 'GT'),
        supportedLocales: const [Locale('es', 'GT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AppShell(
          accountRepository: accountRepository,
          movementRepository: movementRepository,
          installmentRepository: installmentRepository,
          appearanceViewModel: appearanceViewModel,
          enableInstallmentPolling: enableInstallmentPolling,
        ),
      ),
    );
  }
}
