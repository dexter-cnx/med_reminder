import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/medication.dart';
import 'package:med_reminder_offline/features/medication/domain/entities/scheduled_dose.dart';
import 'package:med_reminder_offline/features/refill/domain/entities/refill_event.dart';
import 'package:med_reminder_offline/features/timeline/application/build_daily_timeline.dart';
import 'package:med_reminder_offline/features/timeline/domain/entities/timeline_item.dart';
import 'package:med_reminder_offline/shared/layout/responsive_layout.dart';

void main() {
  test('daily timeline includes same-day refill events in time order', () {
    final medication = Medication(
      id: 'med-1',
      name: 'Vitamin C',
      times: const <String>['08:00'],
      createdAt: DateTime(2026, 8, 20),
    );
    final dose = ScheduledDose(
      medication: medication,
      scheduledAt: DateTime(2026, 8, 22, 8),
    );
    final refill = RefillEvent(
      id: 'refill-1',
      medicationId: medication.id,
      quantity: 20,
      createdAt: DateTime(2026, 8, 22, 10, 30),
      note: 'Pharmacy',
    );
    final yesterday = RefillEvent(
      id: 'refill-old',
      medicationId: medication.id,
      quantity: 10,
      createdAt: DateTime(2026, 8, 21, 18),
    );

    final items = buildDailyTimeline(
      scheduledDoses: <ScheduledDose>[dose],
      refillEvents: <RefillEvent>[refill, yesterday],
      medicationNames: <String, String>{medication.id: medication.name},
      day: DateTime(2026, 8, 22),
    );

    expect(items, hasLength(2));
    expect(items.first, isA<MedicationDoseTimelineItem>());
    final refillItem = items.last as RefillTimelineItem;
    expect(refillItem.event.id, 'refill-1');
    expect(refillItem.medicationName, 'Vitamin C');
  });

  test('ratio-first classifier separates phone and tablet shapes', () {
    final phonePortrait = ResponsiveLayoutInfo.fromSize(
      const Size(390, 844),
    );
    final phoneLandscape = ResponsiveLayoutInfo.fromSize(
      const Size(844, 390),
    );
    final tabletPortrait = ResponsiveLayoutInfo.fromSize(
      const Size(834, 1194),
    );
    final tabletLandscape = ResponsiveLayoutInfo.fromSize(
      const Size(1194, 834),
    );

    expect(phonePortrait.isMobile, isTrue);
    expect(phoneLandscape.isMobile, isTrue);
    expect(tabletPortrait.isTablet, isTrue);
    expect(tabletLandscape.isTablet, isTrue);
    expect(tabletLandscape.primaryPaneFraction, closeTo(0.62, 0.001));
    expect(tabletLandscape.secondaryPaneFraction, closeTo(0.38, 0.001));
  });

  test('small square viewport keeps mobile safety classification', () {
    final compactSquare = ResponsiveLayoutInfo.fromSize(const Size(500, 500));

    expect(compactSquare.shapeRatio, 1);
    expect(compactSquare.isMobile, isTrue);
  });
}
