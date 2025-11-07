import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:ilgabbiano/models/order.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/widgets/custom_app_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  _OrderHistoryScreenState createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SessionManager _sessionManager = SessionManager();
  Future<List<Order>>? _orders;
  String _filter = 'all'; // all | en attente | acceptée | refusée

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

  // Old status helpers (icon/color) removed after redesign.

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
          // Apply filter
          List<Order> orders = snapshot.data!;
          if (_filter != 'all') {
            orders = orders.where((o) => o.status.toLowerCase() == _filter.toLowerCase()).toList();
          }

          return Column(
            children: [
              // Filters
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _StatusChip(label: 'Tous', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'En attente', selected: _filter == 'en attente', onTap: () => setState(() => _filter = 'en attente')),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'Acceptée', selected: _filter == 'acceptée', onTap: () => setState(() => _filter = 'acceptée')),
                    const SizedBox(width: 8),
                    _StatusChip(label: 'Refusée', selected: _filter == 'refusée', onTap: () => setState(() => _filter = 'refusée')),
                  ]),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: BrandPalette.ordersGradient),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.receipt_long, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${AppLocalizations.of(context).t('order_label')} #${order.id} • ${order.total.toStringAsFixed(2)}€',
                                          style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text('${AppLocalizations.of(context).t('pickup_time_label')}: ${order.pickupTime} • ${AppLocalizations.of(context).t('payment_label')}: ${order.paymentMethod}',
                                          style: GoogleFonts.lato(color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                _StatusPill(status: order.status),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (80 * index).ms);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(color: selected ? Theme.of(context).colorScheme.primary : null, fontWeight: FontWeight.w700),
      shape: StadiumBorder(side: BorderSide(color: Theme.of(context).dividerColor)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg;
    switch (s) {
      case 'acceptée':
        bg = Colors.green;
        break;
      case 'refusée':
        bg = Colors.redAccent;
        break;
      default: // en attente
        bg = Colors.orange;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}