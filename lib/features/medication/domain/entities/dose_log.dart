enum DoseStatus { pending, taken, skipped, snoozed }

/// A persisted user action for one medication dose.
///
/// Scheduled doses keep [scheduledAt] as their semantic identity together with
/// [medId]. PRN/as-needed support can evolve this event model without adding
/// PRN-specific state to [Medication].
class DoseLog {
  const DoseLog({
    required this.id,
    required this.medId,
    required this.scheduledAt,
    this.takenAt,
    this.status = DoseStatus.pending,
  });

  final String id;
  final String medId;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final DoseStatus status;

  bool get isTaken => status == DoseStatus.taken;
}
