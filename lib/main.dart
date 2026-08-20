import 'dart:async';
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
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Uncaught platform/Dart error: $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  };

  try {
    await _bootstrapApplication();
  } catch (error, stackTrace) {
    debugPrint('Application bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(StartupFailureApp(error: error));
  }
}

Future<void> _bootstrapApplication() async {
  await EasyLocalization.ensureInitialized();
  await Hive.initFlutter();

  final medsBox = await Hive.openBox<dynamic>('meds');
  final logsBox = await Hive.openBox<dynamic>('logs');

  final localDataSource = HiveMedicationLocalDataSource(
    medicationBox: medsBox,
    doseLogBox: logsBox,
  );
  final medicationRepository = LocalMedicationRepository(localDataSource);
  final doseLogRepository = LocalDoseLogRepository(localDataSource);
  const reminderScheduler = LocalMedicationReminderScheduler();
  const photoStore = LocalMedicationPhotoStore();

  // Only prune after a successful repository read. If storage is corrupt,
  // deleting every photo as "unreferenced" would turn a recoverable data
  // failure into permanent file loss.
  await medicationRepository.readAll().fold(
        onSuccess: (medications) => photoStore.pruneOrphaned(
          medications
              .map((medication) => medication.imagePath)
              .whereType<String>(),
        ),
        onFailure: (_) async => 0,
      );

  // Render the application before touching notification/timezone plugins.
  // Some iOS plugin calls can wait on native state or permissions. They must
  // never hold the first Flutter frame hostage.
  runApp(
    EasyLocalization(
      supportedLocales: supportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(medicationRepository),
          doseLogRepositoryProvider.overrideWithValue(doseLogRepository),
          medicationReminderSchedulerProvider.overrideWithValue(
            reminderScheduler,
          ),
          medicationPhotoStoreProvider.overrideWithValue(photoStore),
        ],
        child: const MedReminderApp(),
      ),
    ),
  );

  unawaited(_initializeNotificationsAfterLaunch());
}

Future<void> _initializeNotificationsAfterLaunch() async {
  // Give Flutter an opportunity to submit the first frame before invoking
  // native notification/timezone channels.
  await Future<void>.delayed(Duration.zero);
  try {
    await NotificationService.init();
  } catch (error, stackTrace) {
    debugPrint('Notification initialization failed after launch: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Med Reminder could not finish startup.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SelectableText(error.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MedReminderApp extends ConsumerStatefulWidget {
  const MedReminderApp({super.key});

  @override
  ConsumerState<MedReminderApp> createState() => _MedReminderAppState();
}

class _MedReminderAppState extends ConsumerState<MedReminderApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
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
      // rescheduleAll iterates the Medication state and uses both medication
      // expiry and DoseLog-derived remaining stock before scheduling anything.
      await ref
          .read(medsProvider.notifier)
          .rescheduleAll(ref.read(logsProvider));
    } catch (error, stackTrace) {
      debugPrint('Timezone refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Med Reminder',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4A90D9),
      ),
      home: const HomeScreen(),
    );
  }
}
