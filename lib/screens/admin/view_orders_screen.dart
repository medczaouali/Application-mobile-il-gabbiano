import 'package:flutter/material.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/order.dart';
import 'package:ilgabbiano/models/user.dart';
import 'package:ilgabbiano/widgets/order_card.dart';
import 'package:ilgabbiano/l10n/strings.dart';

class ViewOrdersScreen extends StatefulWidget {
  @override
  _ViewOrdersScreenState createState() => _ViewOrdersScreenState();
}

class _ViewOrdersScreenState extends State<ViewOrdersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    final orders = await _dbHelper.getOrders();
    final List<Map<String, dynamic>> orderDetails = [];
    for (var order in orders) {
      final user = await _dbHelper.getUserById(order.userId);
      orderDetails.add({'order': order, 'user': user});
    }
    return orderDetails;
  }

  Future<void> _updateOrderStatus(Order order, String status) async {
    await _dbHelper.updateOrderStatus(order.id!, status);
    // Prepare future first so setState's closure is synchronous
    final future = _loadOrders();
    setState(() {
      _ordersFuture = future;
    });
    await future;
  }

  Future<void> _confirmAndChangeStatus(Order order, String newStatus) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(Strings.confirmChangeStatusTitle),
        content: Text(Strings.confirmChangeStatusMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(Strings.cancel)),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: Text(Strings.confirm)),
        ],
      ),
    );

    if (confirm == true) {
      await _updateOrderStatus(order, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statut mis à jour.')));
    }
  }

  // Formatting and status color helpers moved to `OrderCard` widget.

  // Order card rendering extracted to `lib/widgets/order_card.dart`.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Gérer les commandes')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text('Aucune commande pour le moment.'));

          final orderItems = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              final future = _loadOrders();
              setState(() {
                _ordersFuture = future;
              });
              await future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              itemCount: orderItems.length,
              itemBuilder: (context, index) {
                final Order order = orderItems[index]['order'];
                final User? user = orderItems[index]['user'];
                return OrderCard(
                  order: order,
                  user: user,
                  onChangeStatus: (newStatus) async => _confirmAndChangeStatus(order, newStatus),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
