import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/appointment/presentation/providers/appointment_providers.dart';
import '../features/backup/presentation/providers/backup_restore_providers.dart';
import '../features/refill/presentation/providers/refill_providers.dart';
import '../features/timeline/application/build_daily_timeline.dart';
import '../features/timeline/domain/entities/timeline_item.dart';
import 'meds_provider.dart';

/// App-level composition provider for the Today timeline.
///
/// Cross-feature joins live here rather than inside Timeline feature internals
/// or Home widgets, preserving feature ownership boundaries.
final dailyTimelineProvider = Provider<List<TimelineItem>>((ref) {
  // Trigger backup-restore staging maintenance once per app ProviderScope when
  // the operational Home timeline is first composed. The FutureProvider is
  // intentionally not awaited: stale-stage cleanup is maintenance-only and
  // must never block rendering or turn a cleanup failure into startup failure.
  ref.watch(backupRestoreMaintenanceProvider);

  final medications = ref.watch(medsProvider);
  final names = <String, String>{
    for (final medication in medications) medication.id: medication.name,
  };

  return buildDailyTimeline(
    scheduledDoses: ref.watch(todayDosesProvider),
    refillEvents: ref.watch(refillEventsProvider),
    appointments: ref.watch(appointmentsProvider),
    medicationNames: names,
    day: DateTime.now(),
  );
});
