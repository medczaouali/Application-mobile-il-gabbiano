import 'dart:convert';
import 'package:ilgabbiano/models/menu_item.dart';

class Order {
  final int? id;
  final int userId;
  final List<MenuItem> items;
  final double total;
  final String pickupTime;
  final String paymentMethod;
  final String status;

  Order({
    this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.pickupTime,
    required this.paymentMethod,
    this.status = 'en attente',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'items': jsonEncode(items.map((item) => item.toMap()).toList()),
      'total': total,
      'pickup_time': pickupTime,
      'payment_method': paymentMethod,
      'status': status,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      userId: map['user_id'],
      items: (jsonDecode(map['items']) as List)
          .map((item) => MenuItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      total: map['total'],
      pickupTime: map['pickup_time'],
      paymentMethod: map['payment_method'],
      status: map['status'],
    );
  }
}