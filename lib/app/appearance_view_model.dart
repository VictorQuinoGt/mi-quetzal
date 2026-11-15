import 'package:flutter/material.dart';

import '../data/repositories/settings_repository.dart';
import '../domain/models/app_appearance.dart';

class AppearanceViewModel extends ChangeNotifier {
  AppearanceViewModel(this._repository);

  final SettingsRepository _repository;
  AppAppearance _appearance = AppAppearance.system;
  bool _isSaving = false;
  bool _disposed = false;
  String? _error;

  AppAppearance get appearance => _appearance;
  bool get isSaving => _isSaving;
  String? get error => _error;

  ThemeMode get themeMode => switch (_appearance) {
    AppAppearance.system => ThemeMode.system,
    AppAppearance.light => ThemeMode.light,
    AppAppearance.dark => ThemeMode.dark,
  };

  Future<void> load() async {
    try {
      _appearance = await _repository.getAppearance();
      _error = null;
    } catch (_) {
      _error = 'No se pudo recuperar la apariencia. Se usará la del sistema.';
    }
    _notify();
  }

  Future<void> select(AppAppearance appearance) async {
    if (_isSaving || appearance == _appearance) return;
    final previous = _appearance;
    _appearance = appearance;
    _isSaving = true;
    _error = null;
    _notify();
    try {
      await _repository.saveAppearance(appearance);
    } catch (_) {
      _appearance = previous;
      _error = 'No se pudo guardar la apariencia. Inténtalo de nuevo.';
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
