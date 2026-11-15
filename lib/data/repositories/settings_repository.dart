import '../../domain/models/app_appearance.dart';

abstract interface class SettingsRepository {
  Future<AppAppearance> getAppearance();
  Future<void> saveAppearance(AppAppearance appearance);
}
