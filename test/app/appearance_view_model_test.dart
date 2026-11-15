import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_quetzal/app/appearance_view_model.dart';
import 'package:mi_quetzal/domain/models/app_appearance.dart';

import '../support/fake_settings_repository.dart';

void main() {
  test(
    'Sistema es el valor inicial y se restaura la elección al reiniciar',
    () async {
      final repository = FakeSettingsRepository();
      final first = AppearanceViewModel(repository);
      final reopened = AppearanceViewModel(repository);
      addTearDown(first.dispose);
      addTearDown(reopened.dispose);
      expect(first.themeMode, ThemeMode.system);
      await first.select(AppAppearance.dark);
      await reopened.load();
      expect(reopened.themeMode, ThemeMode.dark);
      await reopened.select(AppAppearance.light);
      expect(reopened.themeMode, ThemeMode.light);
      await reopened.select(AppAppearance.system);
      expect(repository.appearance, AppAppearance.system);
    },
  );

  test(
    'Un fallo de lectura conserva Sistema y permite volver a guardar',
    () async {
      final repository = FakeSettingsRepository()..failRead = true;
      final vm = AppearanceViewModel(repository);
      addTearDown(vm.dispose);
      await vm.load();
      expect(vm.themeMode, ThemeMode.system);
      expect(vm.error, isNotNull);
      await vm.select(AppAppearance.dark);
      expect(vm.error, isNull);
      expect(repository.appearance, AppAppearance.dark);
    },
  );

  test('Un fallo al guardar revierte el tema y permite reintentar', () async {
    final repository = FakeSettingsRepository()..failWrite = true;
    final vm = AppearanceViewModel(repository);
    addTearDown(vm.dispose);
    await vm.select(AppAppearance.dark);
    expect(vm.themeMode, ThemeMode.system);
    expect(repository.appearance, AppAppearance.system);
    expect(vm.error, contains('No se pudo guardar'));
    expect(vm.isSaving, isFalse);
    repository.failWrite = false;
    await vm.select(AppAppearance.dark);
    expect(vm.themeMode, ThemeMode.dark);
    expect(vm.error, isNull);
  });

  test('Bloquea selecciones concurrentes mientras se guarda', () async {
    final write = Completer<void>();
    final repository = FakeSettingsRepository()..pendingWrite = write.future;
    final vm = AppearanceViewModel(repository);
    addTearDown(vm.dispose);
    final saving = vm.select(AppAppearance.dark);
    expect(vm.isSaving, isTrue);
    expect(vm.themeMode, ThemeMode.dark);
    await vm.select(AppAppearance.light);
    write.complete();
    await saving;
    expect(repository.appearance, AppAppearance.dark);
    expect(vm.isSaving, isFalse);
  });
}
