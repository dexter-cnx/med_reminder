import 'stock_event.dart';

/// Calculates a current stock balance from an initial amount plus immutable
/// inventory movements for one item.
///
/// This primitive is intentionally domain-neutral. It does not clamp negative
/// values because individual feature domains may need different policies.
int calculateStockBalance({
  required String itemId,
  required int initialAmount,
  Iterable<StockEvent> events = const <StockEvent>[],
}) {
  return events.where((event) => event.itemId == itemId).fold<int>(
        initialAmount,
        (balance, event) => balance + event.quantityDelta,
      );
}
