import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/medication/data/datasources/medication_local_data_source.dart';
import 'features/medication/data/repositories/local_medication_repository.dart';
import 'features/medication/data/services/local_medication_services.dart';
import 'features/medication/presentation/viewmodels/medication_view_model.dart';
import 'l10n/csv_loader.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Hive.initFlutter();

  final medsBox = await Hive.openBox<dynamic>('meds');
  final logsBox = await Hive.openBox<dynamic>('logs');
  await NotificationService.init();

  final localDataSource = HiveMedicationLocalDataSource(
    medicationBox: medsBox,
    doseLogBox: logsBox,
  );

  final locales = await SingleCsvAssetLoader.detectLocalesFromCsv(
    'assets/translations.csv',
  );

  runApp(
    EasyLocalization(
      supportedLocales: locales,
      path: 'assets/translations.csv',
      fallbackLocale: const Locale('en'),
      assetLoader: const SingleCsvAssetLoader(),
      child: ProviderScope(
        overrides: [
          medicationRepositoryProvider.overrideWithValue(
            LocalMedicationRepository(localDataSource),
          ),
          doseLogRepositoryProvider.overrideWithValue(
            LocalDoseLogRepository(localDataSource),
          ),
          medicationReminderSchedulerProvider.overrideWithValue(
            const LocalMedicationReminderScheduler(),
          ),
          medicationPhotoStoreProvider.overrideWithValue(
            const LocalMedicationPhotoStore(),
          ),
        ],
        child: const MedReminderApp(),
      ),
    ),
  );
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
      _refreshTimezone();
    }
  }

  Future<void> _refreshTimezone() async {
    final changed = await NotificationService.refreshTimezoneIfChanged();
    if (!changed || !mounted) return;
    await ref.read(medsProvider.notifier).rescheduleAll();
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
