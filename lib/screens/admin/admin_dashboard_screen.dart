
import 'package:flutter/material.dart';
import '../../services/session_manager.dart';
import '../../db/database_helper.dart';
import '../auth/login_screen.dart';
import 'manage_users_screen.dart';
import 'manage_menu_screen.dart';
import 'manage_reservations_screen.dart';
import 'view_feedbacks_screen.dart';
import 'view_complaints_screen.dart';
import 'view_orders_screen.dart';
import '../../l10n/strings.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SessionManager _sessionManager = SessionManager();
  final DatabaseHelper _db = DatabaseHelper();

  int _pendingReservations = 0;
  int _pendingOrders = 0;
  int _pendingComplaints = 0;
  // Optionally used for spinners in the future; keeping logic simple for now.
  // bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final res = await Future.wait<int>([
        _db.countPendingReservations(),
        _db.countPendingOrders(),
        _db.countPendingComplaints(),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingReservations = res[0];
        _pendingOrders = res[1];
        _pendingComplaints = res[2];
      });
    } catch (_) {
      if (!mounted) return;
  setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard Admin'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _sessionManager.clearSession();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _loadCounts,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCounts,
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildDashboardItem(context, 'Gérer les Utilisateurs', Icons.people, ManageUsersScreen()),
            _buildDashboardItem(context, 'Gérer le Menu', Icons.restaurant_menu, ManageMenuScreen()),
            _buildDashboardItem(context, 'Gérer les Réservations', Icons.calendar_today, ManageReservationsScreen(), badgeCount: _pendingReservations),
            _buildDashboardItem(context, 'Voir les Feedbacks', Icons.feedback, ViewFeedbacksScreen()),
            _buildDashboardItem(context, Strings.ordersTitle, Icons.receipt, ViewOrdersScreen(), badgeCount: _pendingOrders),
            _buildDashboardItem(context, 'Voir les Réclamations', Icons.report_problem, ViewComplaintsScreen(), badgeCount: _pendingComplaints),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardItem(BuildContext context, String title, IconData icon, Widget screen, {int? badgeCount}) {
    final count = (badgeCount ?? 0);
    final hasBadge = count > 0;
    String display = count > 99 ? '99+' : '$count';

    Widget card = Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
          // Reload counts when returning
          _loadCounts();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50.0),
            const SizedBox(height: 10.0),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    if (!hasBadge) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          right: 12,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            constraints: const BoxConstraints(minWidth: 22, minHeight: 18),
            child: Center(
              child: Text(
                display,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
