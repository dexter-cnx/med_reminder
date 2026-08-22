import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/theme/app_theme.dart';

void main() {
  test('Besyu Blue is always the fixed fallback theme', () {
    final catalog = AppThemeCatalog.fromJson('{"themes": []}');

    expect(catalog.themes, hasLength(1));
    expect(catalog.themes.single.id, defaultAppThemeId);
    expect(catalog.definitionFor('unknown').id, defaultAppThemeId);
    expect(catalog.themeFor('unknown').useMaterial3, isTrue);
  });

  test('asset themes can be added without changing Dart theme ids', () {
    final catalog = AppThemeCatalog.fromJson('''
      {
        "themes": [
          {
            "id": "ocean",
            "name": {"en": "Ocean", "th": "Ocean"},
            "seed": "#006699",
            "brightness": "light",
            "surfaceTintStrength": 0.03
          },
          {
            "id": "night_ocean",
            "name": {"en": "Night Ocean"},
            "seed": "#6688FF",
            "brightness": "dark",
            "surfaceTintStrength": 0.08
          }
        ]
      }
    ''');

    expect(catalog.themes.map((theme) => theme.id), [
      defaultAppThemeId,
      'ocean',
      'night_ocean',
    ]);
    expect(catalog.themeFor('ocean').brightness, Brightness.light);
    expect(catalog.themeFor('night_ocean').brightness, Brightness.dark);
  });

  test('asset catalog cannot replace the fixed Besyu Blue fallback', () {
    final catalog = AppThemeCatalog.fromJson('''
      {
        "themes": [
          {
            "id": "besyu_blue",
            "name": {"en": "Override"},
            "seed": "#FF0000",
            "brightness": "dark"
          }
        ]
      }
    ''');

    expect(catalog.themes, hasLength(1));
    expect(catalog.themes.single.id, defaultAppThemeId);
    expect(catalog.themes.single.brightness, Brightness.light);
    expect(catalog.themes.single.seedColor, const Color(0xFF4A90D9));
  });

  test('invalid catalog entries are ignored instead of breaking fallback', () {
    final catalog = AppThemeCatalog.fromJson('''
      {
        "themes": [
          {"id": "bad-color", "name": {"en": "Bad"}, "seed": "nope", "brightness": "light"},
          {"id": "bad-mode", "name": {"en": "Bad"}, "seed": "#112233", "brightness": "sepia"}
        ]
      }
    ''');

    expect(catalog.themes, hasLength(1));
    expect(catalog.themeFor('bad-color').brightness, Brightness.light);
  });
}
