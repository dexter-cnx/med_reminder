import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../appointment/presentation/providers/appointment_providers.dart';
import '../../../medication/presentation/viewmodels/medication_view_model.dart';
import '../../../medication_checkin/presentation/providers/medication_check_in_providers.dart';
import '../../../refill/presentation/providers/refill_providers.dart';
import '../../application/build_doctor_visit_summary.dart';
import '../../domain/entities/doctor_visit_summary.dart';

final doctorVisitSummaryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final doctorVisitSummaryNowProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(doctorVisitSummaryClockProvider)(),
);

final doctorVisitSummaryProvider = Provider.autoDispose<DoctorVisitSummary>((
  ref,
) {
  const builder = BuildDoctorVisitSummary();
  return builder(
    now: ref.watch(doctorVisitSummaryNowProvider),
    medications: ref.watch(medsProvider),
    doseLogs: ref.watch(logsProvider),
    refillEvents: ref.watch(refillEventsProvider),
    checkIns: ref.watch(medicationCheckInsProvider),
    appointments: ref.watch(appointmentsProvider),
  );
});
