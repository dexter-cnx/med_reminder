import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const appThemeSettingKey = 'app_theme_id';

enum AppThemeId {
  besyuBlue('besyu_blue'),
  warmSand('warm_sand'),
  sageCare('sage_care'),
  lavenderCalm('lavender_calm'),
  midnight('midnight');

  const AppThemeId(this.storageValue);

  final String storageValue;

  static AppThemeId fromStorage(Object? value) {
    if (value is String) {
      for (final theme in values) {
        if (theme.storageValue == value) return theme;
      }
    }
    return AppThemeId.besyuBlue;
  }
}

final appThemeProvider = StateNotifierProvider<AppThemeController, AppThemeId>(
  (ref) => throw UnimplementedError('appThemeProvider must be overridden'),
);

class AppThemeController extends StateNotifier<AppThemeId> {
  AppThemeController(this._settings)
      : super(AppThemeId.fromStorage(_settings.get(appThemeSettingKey)));

  final Box<dynamic> _settings;

  Future<void> select(AppThemeId theme) async {
    if (state == theme) return;
    await _settings.put(appThemeSettingKey, theme.storageValue);
    state = theme;
  }
}

abstract final class AppThemeCatalog {
  static ThemeData themeFor(AppThemeId id) {
    switch (id) {
      case AppThemeId.besyuBlue:
        return _build(
          seed: const Color(0xFF4A90D9),
          brightness: Brightness.light,
          surfaceTintStrength: 0.05,
        );
      case AppThemeId.warmSand:
        return _build(
          seed: const Color(0xFFB47B45),
          brightness: Brightness.light,
          surfaceTintStrength: 0.02,
        );
      case AppThemeId.sageCare:
        return _build(
          seed: const Color(0xFF5D8068),
          brightness: Brightness.light,
          surfaceTintStrength: 0.03,
        );
      case AppThemeId.lavenderCalm:
        return _build(
          seed: const Color(0xFF7C6BA8),
          brightness: Brightness.light,
          surfaceTintStrength: 0.04,
        );
      case AppThemeId.midnight:
        return _build(
          seed: const Color(0xFF8DA4FF),
          brightness: Brightness.dark,
          surfaceTintStrength: 0.08,
        );
    }
  }

  static ThemeData _build({
    required Color seed,
    required Brightness brightness,
    required double surfaceTintStrength,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: Color.alphaBlend(
        scheme.primary.withValues(alpha: surfaceTintStrength),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
