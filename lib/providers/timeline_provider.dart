import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/refill/presentation/providers/refill_providers.dart';
import '../features/timeline/application/build_daily_timeline.dart';
import '../features/timeline/domain/entities/timeline_item.dart';
import 'meds_provider.dart';

/// App-level composition provider for the Today timeline.
///
/// Cross-feature joins live here rather than inside Timeline feature internals
/// or Home widgets, preserving feature ownership boundaries.
final dailyTimelineProvider = Provider<List<TimelineItem>>((ref) {
  final medications = ref.watch(medsProvider);
  final names = <String, String>{
    for (final medication in medications) medication.id: medication.name,
  };

  return buildDailyTimeline(
    scheduledDoses: ref.watch(todayDosesProvider),
    refillEvents: ref.watch(refillEventsProvider),
    medicationNames: names,
    day: DateTime.now(),
  );
});
