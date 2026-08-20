/// Immutable stock-in event for a medication refill.
///
/// Refill history is deliberately separate from Medication and DoseLog so
/// inventory remains event-derived and historical refill information is not
/// lost when current medication settings change.
class RefillEvent {
  const RefillEvent({
    required this.id,
    required this.medicationId,
    required this.quantity,
    required this.createdAt,
    this.note,
  }) : assert(quantity > 0, 'Refill quantity must be positive.');

  final String id;
  final String medicationId;
  final int quantity;
  final DateTime createdAt;
  final String? note;
}
