import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'l10n/csv_loader.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('meds');
  await Hive.openBox('logs');
  await NotificationService.init();

  final locales = await SingleCsvAssetLoader.detectLocalesFromCsv('assets/translations.csv');
  runApp(
    EasyLocalization(
      supportedLocales: locales,
      path: 'assets/translations.csv',
      fallbackLocale: const Locale('en'),
      assetLoader: const SingleCsvAssetLoader(),
      child: const ProviderScope(child: MedReminderApp()),
    ),
  );
}

class MedReminderApp extends StatelessWidget {
  const MedReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Med Reminder',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF4A90D9)),
      home: const HomeScreen(),
    );
  }
}
