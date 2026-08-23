import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/result/result.dart';
import 'package:med_reminder_offline/features/medication_checkin/application/query_medication_check_ins.dart';
import 'package:med_reminder_offline/features/medication_checkin/application/record_medication_check_in.dart';
import 'package:med_reminder_offline/features/medication_checkin/domain/entities/medication_check_in.dart';
import 'package:med_reminder_offline/features/medication_checkin/domain/repositories/medication_check_in_repository.dart';

void main() {
  test('record use case persists trimmed factual observation', () async {
    final repository = _MemoryCheckInRepository();
    final recordedAt = DateTime(2026, 8, 23, 16, 30);
    final useCase = RecordMedicationCheckIn(
      repository,
      now: () => recordedAt,
    );

    final result = await useCase(
      medicationId: 'med-1',
      kind: MedicationCheckInKind.nausea,
      note: '  after lunch  ',
    );

    final checkIn = result.fold(
      onSuccess: (value) => value,
      onFailure: (failure) => throw StateError(failure.message),
    );
    expect(checkIn.id, isNotEmpty);
    expect(checkIn.medicationId, 'med-1');
    expect(checkIn.recordedAt, recordedAt);
    expect(checkIn.kind, MedicationCheckInKind.nausea);
    expect(checkIn.note, 'after lunch');
    expect(repository.items.single.id, checkIn.id);
  });

  test('query isolates medication and returns newest first', () {
    final query = const QueryMedicationCheckIns();
    final items = <MedicationCheckIn>[
      MedicationCheckIn(
        id: 'old',
        medicationId: 'med-1',
        recordedAt: DateTime(2026, 8, 20),
        kind: MedicationCheckInKind.noIssue,
      ),
      MedicationCheckIn(
        id: 'other-med',
        medicationId: 'med-2',
        recordedAt: DateTime(2026, 8, 23),
        kind: MedicationCheckInKind.rash,
      ),
      MedicationCheckIn(
        id: 'new',
        medicationId: 'med-1',
        recordedAt: DateTime(2026, 8, 22),
        kind: MedicationCheckInKind.dizziness,
      ),
    ];

    final result = query(checkIns: items, medicationId: 'med-1');

    expect(result.map((item) => item.id), <String>['new', 'old']);
  });

  test('query limit applies after medication filter and newest sort', () {
    final result = const QueryMedicationCheckIns()(
      checkIns: <MedicationCheckIn>[
        MedicationCheckIn(
          id: '1',
          medicationId: 'med-1',
          recordedAt: DateTime(2026, 8, 21),
          kind: MedicationCheckInKind.noIssue,
        ),
        MedicationCheckIn(
          id: '2',
          medicationId: 'med-1',
          recordedAt: DateTime(2026, 8, 22),
          kind: MedicationCheckInKind.other,
        ),
      ],
      medicationId: 'med-1',
      limit: 1,
    );

    expect(result.single.id, '2');
  });
}

class _MemoryCheckInRepository implements MedicationCheckInRepository {
  final List<MedicationCheckIn> items = <MedicationCheckIn>[];

  @override
  Result<List<MedicationCheckIn>> readAll() =>
      Success<List<MedicationCheckIn>>(List.unmodifiable(items));

  @override
  Future<Result<void>> append(MedicationCheckIn checkIn) async {
    items
      ..removeWhere((item) => item.id == checkIn.id)
      ..add(checkIn);
    return const Success<void>(null);
  }
}
