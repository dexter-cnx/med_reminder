enum MedicationCheckInKind {
  noIssue,
  dizziness,
  nausea,
  rash,
  other,
}

/// A factual, user-reported observation associated with a medication.
///
/// This record does not assert that the medication caused the reported issue.
class MedicationCheckIn {
  MedicationCheckIn({
    required this.id,
    required this.medicationId,
    required this.recordedAt,
    required this.kind,
    this.note = '',
  });

  final String id;
  final String medicationId;
  final DateTime recordedAt;
  final MedicationCheckInKind kind;
  final String note;

  bool get hasReportedIssue => kind != MedicationCheckInKind.noIssue;
}
