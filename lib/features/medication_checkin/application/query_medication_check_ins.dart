import '../domain/entities/medication_check_in.dart';

class QueryMedicationCheckIns {
  const QueryMedicationCheckIns();

  List<MedicationCheckIn> call({
    required Iterable<MedicationCheckIn> checkIns,
    required String medicationId,
    int? limit,
  }) {
    final items =
        checkIns
            .where((item) => item.medicationId == medicationId)
            .toList(growable: false)
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    if (limit == null || limit >= items.length) {
      return List<MedicationCheckIn>.unmodifiable(items);
    }
    return List<MedicationCheckIn>.unmodifiable(items.take(limit));
  }
}
