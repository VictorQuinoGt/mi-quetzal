import 'package:mi_quetzal/data/repositories/settings_repository.dart';
import 'package:mi_quetzal/domain/models/app_appearance.dart';

class FakeSettingsRepository implements SettingsRepository {
  AppAppearance appearance = AppAppearance.system;
  bool failRead = false;
  bool failWrite = false;
  Future<void>? pendingWrite;

  @override
  Future<AppAppearance> getAppearance() async {
    if (failRead) throw StateError('Fallo de lectura de prueba');
    return appearance;
  }

  @override
  Future<void> saveAppearance(AppAppearance value) async {
    await pendingWrite;
    if (failWrite) throw StateError('Fallo de escritura de prueba');
    appearance = value;
  }
}
