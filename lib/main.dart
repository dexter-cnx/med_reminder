import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/medication/data/datasources/medication_local_data_source.dart';
import 'features/medication/data/repositories/local_medication_repository.dart';
import 'features/medication/data/services/local_medication_services.dart';
import 'features/medication/presentation/viewmodels/medication_view_model.dart';
import 'l10n/generated_locales.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

const _onboardingCompletedKey = 'onboarding_completed';
const _languageCodeKey = 'language_code';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = FlutterError.dumpErrorToConsole;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Uncaught platform/Dart error: $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  };

  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  String _stage = 'Flutter first frame';
  Widget? _readyApp;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      _checkpoint('Initializing localization');
      await EasyLocalization.ensureInitialized()
          .timeout(const Duration(seconds: 5));

      _checkpoint('Initializing local storage');
      await Hive.initFlutter().timeout(const Duration(seconds: 5));

      _checkpoint('Opening medication storage');
      final medsBox = await Hive.openBox<dynamic>('meds')
          .timeout(const Duration(seconds: 5));

      _checkpoint('Opening dose-log storage');
      final logsBox = await Hive.openBox<dynamic>('logs')
          .timeout(const Duration(seconds: 5));

      _checkpoint('Opening app settings');
      final settingsBox = await Hive.openBox<dynamic>('settings')
          .timeout(const Duration(seconds: 5));

      _checkpoint('Loading app themes');
      final themeCatalog = await AppThemeCatalog.load()
          .timeout(const Duration(seconds: 5));

      final localDataSource = HiveMedicationLocalDataSource(
        medicationBox: medsBox,
        doseLogBox: logsBox,
      );
      final medicationRepository = LocalMedicationRepository(localDataSource);
      final doseLogRepository = LocalDoseLogRepository(localDataSource);
      const reminderScheduler = LocalMedicationReminderScheduler();
      const photoStore = LocalMedicationPhotoStore();
      final themeController = AppThemeController(settingsBox, themeCatalog);

      _checkpoint('Checking medication photos');
      await medicationRepository.readAll().fold(
            onSuccess: (medications) => photoStore
                .pruneOrphaned(
                  medications
                      .map((medication) => medication.imagePath)
                      .whereType<String>(),
                )
                .timeout(const Duration(seconds: 5)),
            onFailure: (_) async => 0,
          );

      final onboardingCompleted =
          settingsBox.get(_onboardingCompletedKey) == true;
      final explicitLanguageCode = settingsBox.get(_languageCodeKey);
      final startupLocale = _resolveStartupLocale(
        explicitLanguageCode is String ? explicitLanguageCode : null,
      );

      final app = EasyLocalization(
        supportedLocales: supportedLocales,
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: startupLocale,
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            medicationRepositoryProvider.overrideWithValue(
              medicationRepository,
            ),
            doseLogRepositoryProvider.overrideWithValue(doseLogRepository),
            medicationReminderSchedulerProvider.overrideWithValue(
              reminderScheduler,
            ),
            medicationPhotoStoreProvider.overrideWithValue(photoStore),
            appThemeCatalogProvider.overrideWithValue(themeCatalog),
            appThemeProvider.overrideWith((ref) => themeController),
          ],
          child: BesyuApp(
            initialOnboardingCompleted: onboardingCompleted,
            onLanguageSelected: (languageCode) =>
                settingsBox.put(_languageCodeKey, languageCode),
            onCompleteOnboarding: () async {
              await settingsBox
                  .put(_onboardingCompletedKey, true)
                  .timeout(const Duration(seconds: 5));
            },
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _stage = 'Ready';
        _readyApp = app;
      });

      unawaited(_initializeNotificationsAfterLaunch());
    } catch (error, stackTrace) {
      debugPrint('Application bootstrap failed at "$_stage": $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Locale _resolveStartupLocale(String? explicitLanguageCode) {
    if (explicitLanguageCode != null) {
      for (final locale in supportedLocales) {
        if (locale.languageCode == explicitLanguageCode) return locale;
      }
    }

    final deviceLanguageCode = PlatformDispatcher.instance.locale.languageCode;
    for (final locale in supportedLocales) {
      if (locale.languageCode == deviceLanguageCode) return locale;
    }
    return const Locale('en');
  }

  void _checkpoint(String stage) {
    debugPrint('BOOTSTRAP: $stage');
    if (!mounted) return;
    setState(() => _stage = stage);
  }

  @override
  Widget build(BuildContext context) {
    final readyApp = _readyApp;
    if (readyApp != null) return readyApp;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Besyu',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Beside You.'),
                  const SizedBox(height: 16),
                  if (_error == null) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_stage, textAlign: TextAlign.center),
                  ] else ...[
                    const Text(
                      'Startup failed',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(_stage, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    SelectableText(
                      _error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _initializeNotificationsAfterLaunch() async {
  await Future<void>.delayed(Duration.zero);
  try {
    await NotificationService.init();
  } catch (error, stackTrace) {
    debugPrint('Notification initialization failed after launch: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class BesyuApp extends ConsumerStatefulWidget {
  const BesyuApp({
    required this.initialOnboardingCompleted,
    required this.onCompleteOnboarding,
    required this.onLanguageSelected,
    super.key,
  });

  final bool initialOnboardingCompleted;
  final Future<void> Function() onCompleteOnboarding;
  final Future<void> Function(String languageCode) onLanguageSelected;

  @override
  ConsumerState<BesyuApp> createState() => _BesyuAppState();
}

class _BesyuAppState extends ConsumerState<BesyuApp>
    with WidgetsBindingObserver {
  late bool _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _onboardingCompleted = widget.initialOnboardingCompleted;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshTimezone());
    }
  }

  Future<void> _refreshTimezone() async {
    try {
      final changed = await NotificationService.refreshTimezoneIfChanged();
      if (!changed || !mounted) return;
      await ref
          .read(medsProvider.notifier)
          .rescheduleAll(ref.read(logsProvider));
    } catch (error, stackTrace) {
      debugPrint('Timezone refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _completeOnboarding() async {
    await widget.onCompleteOnboarding();
    if (!mounted) return;
    setState(() => _onboardingCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(appThemeProvider);
    final themeCatalog = ref.watch(appThemeCatalogProvider);
    return MaterialApp(
      title: 'Besyu',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: themeCatalog.themeFor(themeId),
      home: _onboardingCompleted
          ? const HomeScreen()
          : OnboardingScreen(
              onLanguageSelected: widget.onLanguageSelected,
              onRequestNotifications:
                  NotificationService.requestNotificationPermission,
              onRequestExactAlarm: Platform.isAndroid
                  ? NotificationService.requestExactAlarmPermission
                  : null,
              showExactAlarmStep: Platform.isAndroid,
              onComplete: _completeOnboarding,
            ),
    );
  }
}
