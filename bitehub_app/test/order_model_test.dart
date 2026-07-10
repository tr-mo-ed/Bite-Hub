import 'package:flutter_test/flutter_test.dart';

import 'package:bitehub_app/app/data/models/order_model.dart';

void main() {
  test('order display code matches the cafe panel format', () {
    final numericOrder = OrderModel(
      id: 31,
      orderNumber: '4831',
      totalPrice: 12,
      status: 'PREPARING',
      createdAt: DateTime(2026, 6, 12).toIso8601String(),
      items: const [],
    );
    final formattedOrder = OrderModel(
      id: 32,
      orderNumber: 'BH-123456',
      totalPrice: 12,
      status: 'PREPARING',
      createdAt: DateTime(2026, 6, 12).toIso8601String(),
      items: const [],
    );

    expect(numericOrder.displayOrderCode, 'BH-004831');
    expect(formattedOrder.displayOrderCode, 'BH-123456');
  });
}
