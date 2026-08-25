import '../../domain/entities/refill_event.dart';

class RefillRecord {
  const RefillRecord(this.value);

  static const int schemaVersion = 1;

  final Map<String, dynamic> value;

  factory RefillRecord.fromEntity(RefillEvent event) =>
      RefillRecord(<String, dynamic>{
        'schemaVersion': schemaVersion,
        'id': event.id,
        'medicationId': event.medicationId,
        'quantity': event.quantity,
        'createdAt': event.createdAt.toIso8601String(),
        'note': event.note,
      });

  RefillEvent toEntity() {
    final id = value['id'];
    final medicationId = value['medicationId'];
    final quantity = value['quantity'];
    final createdAt = value['createdAt'];
    final note = value['note'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Refill record has an invalid id.');
    }
    if (medicationId is! String || medicationId.isEmpty) {
      throw const FormatException('Refill record has an invalid medicationId.');
    }
    if (quantity is! num || quantity.toInt() <= 0) {
      throw const FormatException('Refill record has an invalid quantity.');
    }
    if (createdAt is! String) {
      throw const FormatException('Refill record has an invalid createdAt.');
    }
    if (note != null && note is! String) {
      throw const FormatException('Refill record has an invalid note.');
    }

    return RefillEvent(
      id: id,
      medicationId: medicationId,
      quantity: quantity.toInt(),
      createdAt: DateTime.parse(createdAt),
      note: note as String?,
    );
  }
}
