import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const appThemeSettingKey = 'app_theme_id';
const defaultAppThemeId = 'besyu_blue';
const _themeCatalogAsset = 'assets/themes/themes.json';

final appThemeCatalogProvider = Provider<AppThemeCatalog>(
  (ref) => throw UnimplementedError(
    'appThemeCatalogProvider must be overridden during bootstrap',
  ),
);

final appThemeProvider = StateNotifierProvider<AppThemeController, String>(
  (ref) => throw UnimplementedError('appThemeProvider must be overridden'),
);

class AppThemeDefinition {
  const AppThemeDefinition({
    required this.id,
    required this.names,
    required this.seedColor,
    required this.brightness,
    required this.surfaceTintStrength,
  });

  final String id;
  final Map<String, String> names;
  final Color seedColor;
  final Brightness brightness;
  final double surfaceTintStrength;

  String displayName(Locale locale) {
    return names[locale.languageCode] ?? names['en'] ?? id;
  }

  static AppThemeDefinition? tryParse(Object? value) {
    if (value is! Map) return null;

    final id = value['id'];
    final seed = value['seed'];
    final brightness = value['brightness'];
    final rawNames = value['name'];
    final rawTint = value['surfaceTintStrength'];

    if (id is! String || id.trim().isEmpty || id == defaultAppThemeId) {
      return null;
    }
    if (seed is! String || brightness is! String || rawNames is! Map) {
      return null;
    }

    final parsedSeed = _parseHexColor(seed);
    final parsedBrightness = switch (brightness) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      _ => null,
    };
    if (parsedSeed == null || parsedBrightness == null) return null;

    final names = <String, String>{};
    for (final entry in rawNames.entries) {
      final key = entry.key;
      final name = entry.value;
      if (key is String && name is String && name.trim().isNotEmpty) {
        names[key] = name.trim();
      }
    }
    if (names.isEmpty) return null;

    final tint = rawTint is num ? rawTint.toDouble() : 0.04;
    if (tint < 0 || tint > 1) return null;

    return AppThemeDefinition(
      id: id.trim(),
      names: Map.unmodifiable(names),
      seedColor: parsedSeed,
      brightness: parsedBrightness,
      surfaceTintStrength: tint,
    );
  }
}

class AppThemeCatalog {
  AppThemeCatalog._(List<AppThemeDefinition> themes)
    : themes = List.unmodifiable(themes),
      _byId = Map.unmodifiable({for (final theme in themes) theme.id: theme});

  final List<AppThemeDefinition> themes;
  final Map<String, AppThemeDefinition> _byId;

  static const fallback = AppThemeDefinition(
    id: defaultAppThemeId,
    names: <String, String>{'en': 'Besyu Blue', 'th': 'Besyu Blue'},
    seedColor: Color(0xFF4A90D9),
    brightness: Brightness.light,
    surfaceTintStrength: 0.05,
  );

  factory AppThemeCatalog.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      final rawThemes = decoded is Map ? decoded['themes'] : null;
      if (rawThemes is! List) return AppThemeCatalog._([fallback]);

      final parsed = <AppThemeDefinition>[fallback];
      final seen = <String>{defaultAppThemeId};
      for (final rawTheme in rawThemes) {
        final theme = AppThemeDefinition.tryParse(rawTheme);
        if (theme == null || !seen.add(theme.id)) continue;
        parsed.add(theme);
      }
      return AppThemeCatalog._(parsed);
    } catch (_) {
      return AppThemeCatalog._([fallback]);
    }
  }

  static Future<AppThemeCatalog> load() async {
    try {
      final source = await rootBundle.loadString(_themeCatalogAsset);
      return AppThemeCatalog.fromJson(source);
    } catch (_) {
      return AppThemeCatalog._([fallback]);
    }
  }

  bool contains(String id) => _byId.containsKey(id);

  AppThemeDefinition definitionFor(String id) => _byId[id] ?? fallback;

  ThemeData themeFor(String id) => _build(definitionFor(id));

  static ThemeData _build(AppThemeDefinition definition) {
    final scheme = ColorScheme.fromSeed(
      seedColor: definition.seedColor,
      brightness: definition.brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: definition.brightness,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: Color.alphaBlend(
        scheme.primary.withValues(alpha: definition.surfaceTintStrength),
        scheme.surface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class AppThemeController extends StateNotifier<String> {
  AppThemeController(this._settings, this._catalog)
    : super(_resolveInitialTheme(_settings, _catalog));

  final Box<dynamic> _settings;
  final AppThemeCatalog _catalog;

  Future<void> select(String themeId) async {
    final resolved = _catalog.contains(themeId) ? themeId : defaultAppThemeId;
    if (state == resolved) return;
    await _settings.put(appThemeSettingKey, resolved);
    state = resolved;
  }

  static String _resolveInitialTheme(
    Box<dynamic> settings,
    AppThemeCatalog catalog,
  ) {
    final stored = settings.get(appThemeSettingKey);
    if (stored is String && catalog.contains(stored)) return stored;
    return defaultAppThemeId;
  }
}

Color? _parseHexColor(String value) {
  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) return null;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return null;
  return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
}
