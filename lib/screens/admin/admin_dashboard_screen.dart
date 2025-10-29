
import 'package:flutter/material.dart';
import '../../services/session_manager.dart';
import '../auth/login_screen.dart';
import 'manage_users_screen.dart';
import 'manage_menu_screen.dart';
import 'manage_reservations_screen.dart';
import 'view_feedbacks_screen.dart';
import 'view_complaints_screen.dart';
import 'view_orders_screen.dart';
import '../../l10n/strings.dart';

class AdminDashboardScreen extends StatelessWidget {
  final SessionManager _sessionManager = SessionManager();

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
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDashboardItem(context, 'Gérer les Utilisateurs', Icons.people, ManageUsersScreen()),
          _buildDashboardItem(context, 'Gérer le Menu', Icons.restaurant_menu, ManageMenuScreen()),
          _buildDashboardItem(context, 'Gérer les Réservations', Icons.calendar_today, ManageReservationsScreen()),
          _buildDashboardItem(context, 'Voir les Feedbacks', Icons.feedback, ViewFeedbacksScreen()),
          _buildDashboardItem(context, Strings.ordersTitle, Icons.receipt, ViewOrdersScreen()),
          _buildDashboardItem(context, 'Voir les Réclamations', Icons.report_problem, ViewComplaintsScreen()),
        ],
      ),
    );
  }

  Widget _buildDashboardItem(BuildContext context, String title, IconData icon, Widget screen) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50.0),
            SizedBox(height: 10.0),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
