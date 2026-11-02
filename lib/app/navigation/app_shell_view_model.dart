import 'package:flutter/foundation.dart';

import 'app_section.dart';

/// Estado de navegación. Los datos financieros tendrán sus propios ViewModels
/// y repositorios cuando se implemente cada módulo.
class AppShellViewModel extends ChangeNotifier {
  AppSection _section = AppSection.home;

  AppSection get section => _section;

  void selectSection(AppSection section) {
    if (_section == section) return;
    _section = section;
    notifyListeners();
  }
}
