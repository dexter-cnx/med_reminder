import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/emergency/application/build_emergency_medical_card.dart';
import 'package:med_reminder_offline/features/emergency/domain/entities/emergency_profile.dart';
import 'package:med_reminder_offline/features/emergency/domain/repositories/emergency_profile_repository.dart';
import 'package:med_reminder_offline/features/emergency/presentation/providers/emergency_profile_providers.dart';
import 'package:med_reminder_offline/features/emergency/presentation/screens/emergency_medical_card_screen.dart';
import 'package:med_reminder_offline/features/emergency/presentation/screens/emergency_profile_settings_screen.dart';

class _MemoryEmergencyProfileRepository implements EmergencyProfileRepository {
  _MemoryEmergencyProfileRepository(this.value);

  EmergencyProfile? value;

  @override
  Result<EmergencyProfile?> read() => Success<EmergencyProfile?>(value);

  @override
  Future<Result<void>> save(EmergencyProfile profile) async {
    value = profile;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> clear() async {
    value = null;
    return const Success<void>(null);
  }
}

Future<void> _pumpLocalizedApp(
  WidgetTester tester, {
  required EmergencyProfileRepository repository,
  required Widget home,
  EmergencyMedicalCard? card,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const <Locale>[Locale('en'), Locale('th')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      child: ProviderScope(
        overrides: <Override>[
          emergencyProfileRepositoryProvider.overrideWithValue(repository),
          if (card != null)
            emergencyMedicalCardProvider.overrideWithValue(card),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sharedPreferencesChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel, (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      return null;
    });
    await EasyLocalization.ensureInitialized();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharedPreferencesChannel, null);
  });

  testWidgets('Emergency Medical Card is read-only and opens profile settings',
      (
    tester,
  ) async {
    const profile = EmergencyProfile(
      displayName: 'Dexter',
      emergencyContactName: 'Contact',
      emergencyContactPhone: '0812345678',
      medicationAllergies: 'None known',
      medicalNotes: 'Local-only note',
    );
    final repository = _MemoryEmergencyProfileRepository(profile);
    final card = EmergencyMedicalCard(
      generatedAt: DateTime(2026, 8, 24),
      profile: profile,
      currentMedications: const [],
    );

    await _pumpLocalizedApp(
      tester,
      repository: repository,
      card: card,
      home: const EmergencyMedicalCardScreen(),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Dexter'), findsOneWidget);
    expect(find.text('Contact · 0812345678'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyProfileSettingsScreen), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(5));
  });

  testWidgets('Emergency profile settings owns edit controls', (tester) async {
    const profile = EmergencyProfile(
      displayName: 'Dexter',
      emergencyContactPhone: '0812345678',
    );
    final repository = _MemoryEmergencyProfileRepository(profile);

    await _pumpLocalizedApp(
      tester,
      repository: repository,
      home: const EmergencyProfileSettingsScreen(),
    );

    expect(find.byType(TextField), findsNWidgets(5));
    expect(find.byIcon(Icons.save_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
