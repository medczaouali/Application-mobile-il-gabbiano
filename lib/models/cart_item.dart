import 'package:ilgabbiano/models/menu_item.dart';

class CartItem {
  final int? id;
  final int userId;
  final int productId;
  int quantity;
  final MenuItem? menuItem; // To hold product details for UI

  CartItem({
    this.id,
    required this.userId,
    required this.productId,
    required this.quantity,
    this.menuItem,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      userId: map['user_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      menuItem: map.containsKey('name') ? MenuItem.fromMap(map) : null,
    );
  }
}