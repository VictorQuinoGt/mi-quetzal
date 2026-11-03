import 'package:flutter/foundation.dart';

import '../../data/repositories/installment_repository.dart';

import 'app_section.dart';

/// Navegación y coordinación de la recuperación de cuotas entre pantallas.
class AppShellViewModel extends ChangeNotifier {
  AppShellViewModel({InstallmentRepository? installmentRepository})
    : _installments = installmentRepository;
  final InstallmentRepository? _installments;
  bool _refreshing = false;
  bool _disposed = false;
  AppSection _section = AppSection.home;

  AppSection get section => _section;

  Future<void> refreshInstallments(
    Iterable<Future<void> Function()> Function() readers,
  ) async {
    if (_refreshing || _disposed || _installments == null) return;
    _refreshing = true;
    try {
      try {
        await _installments.generateDue();
      } catch (_) {
        // Las lecturas siguientes muestran los errores con el estado habitual.
      }
      if (!_disposed) await Future.wait(readers().map((read) => read()));
    } finally {
      _refreshing = false;
    }
  }

  void selectSection(AppSection section) {
    if (_section == section) return;
    _section = section;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
