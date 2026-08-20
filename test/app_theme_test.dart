import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/theme/app_theme.dart';

void main() {
  test('unknown stored theme falls back to Besyu Blue', () {
    expect(AppThemeId.fromStorage('unknown'), AppThemeId.besyuBlue);
    expect(AppThemeId.fromStorage(null), AppThemeId.besyuBlue);
  });

  test('all five themes produce Material 3 themes', () {
    expect(AppThemeId.values, hasLength(5));

    for (final id in AppThemeId.values) {
      final theme = AppThemeCatalog.themeFor(id);
      expect(theme.useMaterial3, isTrue);
    }
  });

  test('Midnight is dark while the other presets are light', () {
    expect(
      AppThemeCatalog.themeFor(AppThemeId.midnight).brightness,
      Brightness.dark,
    );

    for (final id in AppThemeId.values.where(
      (theme) => theme != AppThemeId.midnight,
    )) {
      expect(AppThemeCatalog.themeFor(id).brightness, Brightness.light);
    }
  });

  test('theme presets have distinct primary colors', () {
    final primaryColors = AppThemeId.values
        .map((id) => AppThemeCatalog.themeFor(id).colorScheme.primary)
        .toSet();

    expect(primaryColors, hasLength(AppThemeId.values.length));
  });
}
