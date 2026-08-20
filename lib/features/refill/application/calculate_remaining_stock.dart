import '../../medication/domain/entities/medication.dart';
import '../domain/entities/refill_event.dart';

/// Calculates inventory from immutable stock-in and dose-consumption events.
///
/// This is the future-safe replacement for introducing a mutable persisted
/// `remainingAmount`. Existing callers may continue using Medication.remaining
/// until refill persistence is wired into the application composition root.
int? calculateRemainingStock({
  required Medication medication,
  required Iterable<DoseLog> doseLogs,
  Iterable<RefillEvent> refillEvents = const <RefillEvent>[],
}) {
  final initial = medication.initialAmount;
  if (initial == null) return null;

  final refilled = refillEvents
      .where((event) => event.medicationId == medication.id)
      .fold<int>(0, (sum, event) => sum + event.quantity);
  final consumed = doseLogs
          .where((log) => log.medId == medication.id && log.isTaken)
          .length *
      medication.dosagePerTime;
  final remaining = initial + refilled - consumed;
  return remaining < 0 ? 0 : remaining;
}
