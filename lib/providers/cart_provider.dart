import 'package:flutter/foundation.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/cart_item.dart';
import 'package:ilgabbiano/models/menu_item.dart';

class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  int? _userId;

  List<CartItem> get items => [..._items];

  int get itemCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  double get totalPrice {
    return _items.fold(0.0, (sum, item) {
      return sum + (item.menuItem!.price * item.quantity);
    });
  }

  Future<void> init(int userId) async {
    _userId = userId;
    await _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    if (_userId == null) return;
    final dataList = await _dbHelper.getCartItems(_userId!);
    _items = dataList;
    notifyListeners();
  }

  Future<void> addItem(MenuItem menuItem) async {
    if (_userId == null) return;
    final existingItemIndex = _items.indexWhere((item) => item.productId == menuItem.id);

    if (existingItemIndex >= 0) {
      final existingItem = _items[existingItemIndex];
      final newQuantity = existingItem.quantity + 1;
      await _dbHelper.updateCartItemQuantity(existingItem.id!, newQuantity);
    } else {
      final newItem = CartItem(
        userId: _userId!,
        productId: menuItem.id!,
        quantity: 1,
        menuItem: menuItem,
      );
      await _dbHelper.addToCart(newItem);
    }
    await _loadCartItems();
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    await _dbHelper.updateCartItemQuantity(cartItemId, quantity);
    await _loadCartItems();
  }

  Future<void> removeItem(int cartItemId) async {
    await _dbHelper.removeFromCart(cartItemId);
    await _loadCartItems();
  }

  Future<void> clearCart() async {
    if (_userId == null) return;
    await _dbHelper.clearCart(_userId!);
    _items = [];
    notifyListeners();
  }
}