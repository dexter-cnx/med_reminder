import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/medication_checkin/data/datasources/medication_check_in_local_data_source.dart';
import 'package:med_reminder_offline/features/medication_checkin/data/models/medication_check_in_record.dart';
import 'package:med_reminder_offline/features/medication_checkin/data/repositories/local_medication_check_in_repository.dart';
import 'package:med_reminder_offline/features/medication_checkin/domain/entities/medication_check_in.dart';
import 'package:med_reminder_offline/features/medication_checkin/presentation/providers/medication_check_in_providers.dart';

void main() {
  test('check-in record round-trips factual user-reported data', () {
    final checkIn = MedicationCheckIn(
      id: 'c1',
      medicationId: 'm1',
      recordedAt: DateTime(2026, 8, 22, 18, 30),
      kind: MedicationCheckInKind.dizziness,
      note: 'Noticed after lunch',
    );

    final restored = MedicationCheckInRecord.fromEntity(checkIn).toEntity();

    expect(restored.id, 'c1');
    expect(restored.medicationId, 'm1');
    expect(restored.kind, MedicationCheckInKind.dizziness);
    expect(restored.note, 'Noticed after lunch');
    expect(restored.hasReportedIssue, isTrue);
  });

  test('unknown persisted kind degrades safely to other', () {
    const record = MedicationCheckInRecord(<String, dynamic>{
      'id': 'c1',
      'medicationId': 'm1',
      'recordedAt': '2026-08-22T18:30:00.000',
      'kind': 'future_kind',
      'note': 'User text',
    });

    expect(record.toEntity().kind, MedicationCheckInKind.other);
  });

  test('repository appends history and reads it in timestamp order', () async {
    final dataSource = _MemoryCheckInDataSource();
    final repository = LocalMedicationCheckInRepository(dataSource);

    final later = MedicationCheckIn(
      id: 'later',
      medicationId: 'm1',
      recordedAt: DateTime(2026, 8, 22, 20),
      kind: MedicationCheckInKind.noIssue,
    );
    final earlier = MedicationCheckIn(
      id: 'earlier',
      medicationId: 'm1',
      recordedAt: DateTime(2026, 8, 22, 8),
      kind: MedicationCheckInKind.nausea,
    );

    expect(await repository.append(later), isNotNull);
    expect(await repository.append(earlier), isNotNull);

    final ids = repository.readAll().fold(
          onSuccess: (items) => items.map((item) => item.id).toList(),
          onFailure: (failure) => <String>['failure:${failure.code}'],
        );

    expect(ids, <String>['earlier', 'later']);
  });

  test('view model replaces an existing check-in with the same id', () async {
    final dataSource = _MemoryCheckInDataSource();
    final repository = LocalMedicationCheckInRepository(dataSource);
    final viewModel = MedicationCheckInViewModel(
      repository,
      onFailure: (_) {},
    );

    final first = MedicationCheckIn(
      id: 'same',
      medicationId: 'm1',
      recordedAt: DateTime(2026, 8, 22, 8),
      kind: MedicationCheckInKind.noIssue,
    );
    final replacement = MedicationCheckIn(
      id: 'same',
      medicationId: 'm1',
      recordedAt: DateTime(2026, 8, 22, 9),
      kind: MedicationCheckInKind.nausea,
      note: 'Updated entry',
    );

    expect(await viewModel.append(first), isTrue);
    expect(await viewModel.append(replacement), isTrue);

    expect(viewModel.state, hasLength(1));
    expect(viewModel.state.single.recordedAt, replacement.recordedAt);
    expect(viewModel.state.single.kind, MedicationCheckInKind.nausea);
    expect(viewModel.state.single.note, 'Updated entry');
  });
}

class _MemoryCheckInDataSource implements MedicationCheckInLocalDataSource {
  final Map<String, Map<String, dynamic>> _records = {};

  @override
  List<Map<dynamic, dynamic>> readCheckInRecords() =>
      _records.values.map(Map<dynamic, dynamic>.from).toList(growable: false);

  @override
  Future<void> putCheckInRecord(
    String id,
    Map<String, dynamic> record,
  ) async {
    _records[id] = Map<String, dynamic>.from(record);
  }
}
