import 'package:flutter/foundation.dart';

import '../../data/repositories/installment_repository.dart';
import '../../domain/models/ledger_snapshot.dart';

import 'app_section.dart';

/// Navegación y coordinación de la recuperación de cuotas entre pantallas.
class AppShellViewModel extends ChangeNotifier {
  AppShellViewModel({
    InstallmentRepository? installmentRepository,
    this.refreshTimeout = const Duration(seconds: 15),
  }) : _installments = installmentRepository;
  final InstallmentRepository? _installments;
  final Duration refreshTimeout;
  int _refreshGeneration = 0;
  bool _refreshing = false;
  bool _disposed = false;
  AppSection _section = AppSection.home;

  AppSection get section => _section;

  void invalidateRefresh() => _refreshGeneration++;

  Future<LedgerSnapshot?> refreshInstallments() async {
    if (_refreshing || _disposed || _installments == null) return null;
    final generation = ++_refreshGeneration;
    _refreshing = true;
    try {
      final snapshot = await _installments.generateDue().timeout(
        refreshTimeout,
      );
      return !_disposed && generation == _refreshGeneration ? snapshot : null;
    } catch (_) {
      // Una actualización fallida conserva la última instantánea confirmada.
      return null;
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
