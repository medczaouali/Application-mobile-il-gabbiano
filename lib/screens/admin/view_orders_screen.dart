import 'package:flutter/material.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/order.dart';
import 'package:ilgabbiano/models/user.dart';
import 'package:ilgabbiano/widgets/order_card.dart';
import 'package:ilgabbiano/l10n/strings.dart';

class ViewOrdersScreen extends StatefulWidget {
  const ViewOrdersScreen({super.key});
  @override
  _ViewOrdersScreenState createState() => _ViewOrdersScreenState();
}

class _ViewOrdersScreenState extends State<ViewOrdersScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _statusFilter = 'Tous';
  DateTime? _fromDate;
  DateTime? _toDate;

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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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

          // Apply filters
          final q = _searchController.text.trim().toLowerCase();
          final status = _statusFilter;
          final filtered = orderItems.where((m) {
            final Order o = m['order'];
            final User? u = m['user'];
            final matchesText = q.isEmpty ||
                o.items.any((it) => it.name.toLowerCase().contains(q)) ||
                (u?.name.toLowerCase().contains(q) ?? false) ||
                o.paymentMethod.toLowerCase().contains(q) ||
                o.status.toLowerCase().contains(q);
            bool matchesStatus = true;
            if (status != 'Tous') {
              matchesStatus = o.status.toLowerCase() == status.toLowerCase();
            }
            bool matchesDate = true;
            if (_fromDate != null || _toDate != null) {
              DateTime? pickup;
              try { pickup = DateTime.parse(o.pickupTime).toLocal(); } catch (_) {}
              if (pickup == null) return false;
              if (_fromDate != null && pickup.isBefore(DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day))) matchesDate = false;
              if (_toDate != null && pickup.isAfter(DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23,59,59))) matchesDate = false;
            }
            return matchesText && matchesStatus && matchesDate;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              final future = _loadOrders();
              setState(() {
                _ordersFuture = future;
              });
              await future;
            },
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: _searchFocus,
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Rechercher (client, article, statut, paiement)',
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      FocusScope.of(context).requestFocus(_searchFocus);
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _statusFilter,
                        items: const ['Tous','en attente','acceptée','préparée','prête','livrée','refusée']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(() => _statusFilter = v ?? 'Tous'),
                      ),
                      IconButton(
                        tooltip: 'Filtrer par date',
                        icon: const Icon(Icons.date_range),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: _fromDate != null && _toDate != null ? DateTimeRange(start: _fromDate!, end: _toDate!) : null,
                          );
                          if (picked != null) setState(() { _fromDate = picked.start; _toDate = picked.end; });
                        },
                      ),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('Aucun résultat pour ces filtres.')),
                  )
                else ...[
                  for (final m in filtered)
                    Builder(builder: (context) {
                      final Order order = m['order'];
                      final User? user = m['user'];
                      return OrderCard(
                        order: order,
                        user: user,
                        onChangeStatus: (newStatus) async => _confirmAndChangeStatus(order, newStatus),
                      );
                    })
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
