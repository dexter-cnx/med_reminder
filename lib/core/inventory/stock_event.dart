/// Domain-neutral inventory movement.
///
/// A positive [quantityDelta] adds stock and a negative value consumes or
/// removes stock. Feature domains remain responsible for deciding what their
/// events mean (for example a medication refill or a taken dose).
class StockEvent {
  const StockEvent({
    required this.id,
    required this.itemId,
    required this.quantityDelta,
    required this.occurredAt,
    this.note,
  }) : assert(quantityDelta != 0, 'Stock event delta must not be zero.');

  final String id;
  final String itemId;
  final int quantityDelta;
  final DateTime occurredAt;
  final String? note;
}
