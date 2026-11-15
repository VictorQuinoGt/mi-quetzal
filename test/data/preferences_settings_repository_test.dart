import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/data/repositories/preferences_settings_repository.dart';
import 'package:mi_quetzal/domain/models/app_appearance.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  test(
    'Una instalación nueva o un valor desconocido utiliza Sistema',
    () async {
      final preferences = StoredPreferences();
      final repository = PreferencesSettingsRepository(
        preferences: preferences,
      );
      expect(await repository.getAppearance(), AppAppearance.system);
      preferences.values[PreferencesSettingsRepository.appearanceKey] =
          'unknown';
      expect(await repository.getAppearance(), AppAppearance.system);
    },
  );

  test('Guarda y recupera cada opción al recrear el repositorio', () async {
    final preferences = StoredPreferences();
    for (final appearance in AppAppearance.values) {
      await PreferencesSettingsRepository(preferences: preferences)
          .saveAppearance(appearance);
      final reopened = PreferencesSettingsRepository(preferences: preferences);
      expect(await reopened.getAppearance(), appearance);
    }
  });
}
