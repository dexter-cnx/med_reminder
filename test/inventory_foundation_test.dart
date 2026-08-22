import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder_offline/core/inventory/calculate_stock_balance.dart';
import 'package:med_reminder_offline/core/inventory/stock_event.dart';

void main() {
  test('stock balance primitive is reusable outside medication', () {
    final events = <StockEvent>[
      StockEvent(
        id: 'buy-1',
        itemId: 'tomato',
        quantityDelta: 4,
        occurredAt: DateTime(2026, 8, 22, 8),
      ),
      StockEvent(
        id: 'cook-1',
        itemId: 'tomato',
        quantityDelta: -2,
        occurredAt: DateTime(2026, 8, 22, 12),
      ),
      StockEvent(
        id: 'other-item',
        itemId: 'cucumber',
        quantityDelta: 99,
        occurredAt: DateTime(2026, 8, 22, 13),
      ),
    ];

    expect(
      calculateStockBalance(
        itemId: 'tomato',
        initialAmount: 6,
        events: events,
      ),
      8,
    );
  });

  test('generic inventory may represent a negative balance', () {
    expect(
      calculateStockBalance(
        itemId: 'consumable',
        initialAmount: 1,
        events: <StockEvent>[
          StockEvent(
            id: 'consume-1',
            itemId: 'consumable',
            quantityDelta: -2,
            occurredAt: DateTime(2026, 8, 22),
          ),
        ],
      ),
      -1,
    );
  });
}
