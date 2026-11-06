import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'marketplace.dart';

/// Where an order is in its life. The seller moves it forward
/// (accepted → preparing → ready → completed); the buyer can cancel early
/// or confirm they received it.
enum OrderStatus {
  requested('Pending', Color(0xFFB45309)),
  accepted('Accepted', Color(0xFF16A34A)),
  preparing('Preparing', Color(0xFF2563EB)),
  ready('Ready', Color(0xFF7C3AED)),
  completed('Completed', Color(0xFF15803D)),
  declined('Declined', Color(0xFFDC2626)),
  cancelled('Cancelled', Color(0xFFDC2626));

  const OrderStatus(this.label, this.color);
  final String label;
  final Color color;

  bool get isClosed =>
      this == completed || this == declined || this == cancelled;

  static OrderStatus parse(Object? value) => OrderStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => OrderStatus.requested,
  );
}

enum Fulfilment {
  pickup('Pickup', 'I will collect from the shop', Icons.storefront_outlined),
  delivery(
    'Delivery',
    'Request delivery from the vendor',
    Icons.delivery_dining_outlined,
  );

  const Fulfilment(this.label, this.hint, this.icon);
  final String label;
  final String hint;
  final IconData icon;

  static Fulfilment parse(Object? value) =>
      value == 'delivery' ? Fulfilment.delivery : Fulfilment.pickup;
}

/// An order request from a buyer to a shop (`orders/{id}`). The product's
/// name and price are copied in, so later edits don't change the order.
class MarketOrder {
  const MarketOrder({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.shopId,
    required this.shopName,
    required this.productId,
    required this.productName,
    required this.category,
    required this.priceUgx,
    required this.quantity,
    required this.fulfilment,
    this.unit = '',
    this.note = '',
    this.status = OrderStatus.requested,
    this.createdAt,
    this.times = const {},
  });

  final String id;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String shopId;
  final String shopName;
  final String productId;
  final String productName;
  final MarketCategory category;
  final int priceUgx;
  final String unit;
  final int quantity;
  final Fulfilment fulfilment;
  final String note;
  final OrderStatus status;
  final DateTime? createdAt;

  /// When each status was reached.
  final Map<OrderStatus, DateTime> times;

  int get totalUgx => priceUgx * quantity;

  String get itemName => unit.isEmpty ? productName : '$productName ($unit)';

  /// Short reference shown to people, e.g. "CM-1042".
  String get code => orderCode(id);

  /// Label for the "ready" step, which depends on how it is fulfilled.
  String get readyLabel =>
      fulfilment == Fulfilment.pickup ? 'Ready for Pickup' : 'Out for Delivery';

  factory MarketOrder.fromMap(String id, Map<String, dynamic> data) {
    final rawTimes = data['times'];
    return MarketOrder(
      id: id,
      buyerId: data['buyerId'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? 'Neighbour',
      sellerId: data['sellerId'] as String? ?? '',
      shopId: data['shopId'] as String? ?? '',
      shopName: data['shopName'] as String? ?? 'Shop',
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? 'Product',
      category: MarketCategory.parse(data['category']),
      priceUgx: (data['priceUgx'] as num?)?.toInt() ?? 0,
      unit: data['unit'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      fulfilment: Fulfilment.parse(data['fulfilment']),
      note: data['note'] as String? ?? '',
      status: OrderStatus.parse(data['status']),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      times: {
        if (rawTimes is Map)
          for (final e in rawTimes.entries)
            if (e.value is Timestamp)
              OrderStatus.parse(e.key): (e.value as Timestamp).toDate(),
      },
    );
  }

  Map<String, dynamic> toNewMap() => {
    'buyerId': buyerId,
    'buyerName': buyerName,
    'sellerId': sellerId,
    'shopId': shopId,
    'shopName': shopName,
    'productId': productId,
    'productName': productName,
    'category': category.name,
    'priceUgx': priceUgx,
    'unit': unit,
    'quantity': quantity,
    'fulfilment': fulfilment.name,
    'note': note,
    'status': OrderStatus.requested.name,
    'createdAt': FieldValue.serverTimestamp(),
    'times': {OrderStatus.requested.name: FieldValue.serverTimestamp()},
  };

  MarketOrder copyWith({String? id, OrderStatus? status}) => MarketOrder(
    id: id ?? this.id,
    buyerId: buyerId,
    buyerName: buyerName,
    sellerId: sellerId,
    shopId: shopId,
    shopName: shopName,
    productId: productId,
    productName: productName,
    category: category,
    priceUgx: priceUgx,
    unit: unit,
    quantity: quantity,
    fulfilment: fulfilment,
    note: note,
    status: status ?? this.status,
    createdAt: createdAt,
    times: times,
  );
}

/// "CM-" and four digits made from the document id.
String orderCode(String id) {
  var n = 0;
  for (final c in id.codeUnits) {
    n = (n * 31 + c) % 9000;
  }
  return 'CM-${n + 1000}';
}
