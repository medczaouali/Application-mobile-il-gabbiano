import 'package:flutter/material.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/order.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/widgets/custom_app_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';

class OrderHistoryScreen extends StatefulWidget {
  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SessionManager _sessionManager = SessionManager();
  Future<List<Order>>? _orders;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() async {
    final session = await _sessionManager.getUserSession();
    if (session != null) {
      setState(() {
        _orders = _dbHelper.getOrdersByUser(session['id']);
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'acceptée':
        return Colors.green;
      case 'refusée':
        return Colors.red;
      case 'en attente':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'acceptée':
        return Icons.check_circle;
      case 'refusée':
        return Icons.cancel;
      case 'en attente':
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: AppLocalizations.of(context).t('order_history')),
      body: FutureBuilder<List<Order>>(
        future: _orders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context).t('no_orders'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.all(15),
                  leading: Icon(
                    _getStatusIcon(order.status),
                    color: _getStatusColor(order.status),
                    size: 40,
                  ),
                  title: Text(
                    '${AppLocalizations.of(context).t('order_label')} #${order.id} - ${order.total.toStringAsFixed(2)}€',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      '${AppLocalizations.of(context).t('pickup_time_label')}: ${order.pickupTime}\n${AppLocalizations.of(context).t('payment_label')}: ${order.paymentMethod}'),
                  trailing: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: (100 * index).ms);
            },
          );
        },
      ),
    );
  }
}