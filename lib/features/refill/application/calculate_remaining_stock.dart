import '../../../core/inventory/calculate_stock_balance.dart';
import '../../../core/inventory/stock_event.dart';
import '../../medication/domain/entities/medication.dart';
import '../domain/entities/refill_event.dart';

/// Calculates medication inventory from feature-owned refill and dose events.
///
/// Medication semantics stay in this adapter while the stock aggregation is
/// delegated to the domain-neutral inventory primitive in `core/inventory`.
/// Existing callers may continue using Medication.remaining until refill
/// persistence is wired into the application composition root.
int? calculateRemainingStock({
  required Medication medication,
  required Iterable<DoseLog> doseLogs,
  Iterable<RefillEvent> refillEvents = const <RefillEvent>[],
}) {
  final initial = medication.initialAmount;
  if (initial == null) return null;

  final stockEvents = <StockEvent>[
    for (final event in refillEvents)
      if (event.medicationId == medication.id)
        StockEvent(
          id: 'refill:${event.id}',
          itemId: medication.id,
          quantityDelta: event.quantity,
          occurredAt: event.createdAt,
          note: event.note,
        ),
    for (final log in doseLogs)
      if (log.medId == medication.id &&
          log.isTaken &&
          medication.dosagePerTime != 0)
        StockEvent(
          id: 'dose:${log.id}',
          itemId: medication.id,
          quantityDelta: -medication.dosagePerTime,
          occurredAt: log.takenAt ?? log.scheduledAt,
        ),
  ];

  final remaining = calculateStockBalance(
    itemId: medication.id,
    initialAmount: initial,
    events: stockEvents,
  );

  // Preserve the existing medication-domain behavior. The generic inventory
  // primitive intentionally allows negative balances for other use cases.
  return remaining < 0 ? 0 : remaining;
}
