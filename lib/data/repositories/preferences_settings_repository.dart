import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_appearance.dart';
import 'settings_repository.dart';

class PreferencesSettingsRepository implements SettingsRepository {
  PreferencesSettingsRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const appearanceKey = 'app_appearance';
  final SharedPreferencesAsync _preferences;

  @override
  Future<AppAppearance> getAppearance() async {
    final stored = await _preferences.getString(appearanceKey);
    return AppAppearance.values.firstWhere(
      (appearance) => appearance.name == stored,
      orElse: () => AppAppearance.system,
    );
  }

  @override
  Future<void> saveAppearance(AppAppearance appearance) =>
      _preferences.setString(appearanceKey, appearance.name);
}
