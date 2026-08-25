import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/features/refill/data/datasources/refill_local_data_source.dart';
import 'package:med_reminder_offline/features/refill/data/models/refill_record.dart';
import 'package:med_reminder_offline/features/refill/data/repositories/local_refill_repository.dart';
import 'package:med_reminder_offline/features/refill/domain/entities/refill_event.dart';

void main() {
  test('refill record round-trips without losing domain data', () {
    final event = RefillEvent(
      id: 'r1',
      medicationId: 'm1',
      quantity: 30,
      createdAt: DateTime.utc(2026, 8, 22, 7, 30),
      note: 'pharmacy refill',
    );

    final restored = RefillRecord.fromEntity(event).toEntity();

    expect(restored.id, event.id);
    expect(restored.medicationId, event.medicationId);
    expect(restored.quantity, event.quantity);
    expect(restored.createdAt, event.createdAt);
    expect(restored.note, event.note);
  });

  test(
    'repository persists refills and returns them chronologically',
    () async {
      final dataSource = _MemoryRefillLocalDataSource();
      final repository = LocalRefillRepository(dataSource);

      final later = RefillEvent(
        id: 'r2',
        medicationId: 'm1',
        quantity: 60,
        createdAt: DateTime(2026, 8, 22, 12),
      );
      final earlier = RefillEvent(
        id: 'r1',
        medicationId: 'm1',
        quantity: 30,
        createdAt: DateTime(2026, 8, 21, 12),
      );

      await repository.append(later);
      await repository.append(earlier);

      final events = repository.readAll().fold(
        onSuccess: (items) => items,
        onFailure: (failure) => throw StateError(failure.message),
      );

      expect(events.map((event) => event.id), <String>['r1', 'r2']);
    },
  );

  test('event id is the persistence key and append is retry-safe', () async {
    final dataSource = _MemoryRefillLocalDataSource();
    final repository = LocalRefillRepository(dataSource);
    final event = RefillEvent(
      id: 'r1',
      medicationId: 'm1',
      quantity: 30,
      createdAt: DateTime(2026, 8, 22),
    );

    await repository.append(event);
    await repository.append(event);

    final events = repository.readAll().fold(
      onSuccess: (items) => items,
      onFailure: (failure) => throw StateError(failure.message),
    );

    expect(events, hasLength(1));
    expect(events.single.quantity, 30);
  });
}

class _MemoryRefillLocalDataSource implements RefillLocalDataSource {
  final Map<String, Map<String, dynamic>> _records = {};

  @override
  List<Map<dynamic, dynamic>> readRefillRecords() =>
      _records.values.map(Map<dynamic, dynamic>.from).toList(growable: false);

  @override
  Future<void> putRefillRecord(String id, Map<String, dynamic> record) async {
    _records[id] = Map<String, dynamic>.from(record);
  }
}
