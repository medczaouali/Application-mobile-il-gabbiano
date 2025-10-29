import 'package:flutter/material.dart';
import 'package:ilgabbiano/screens/admin/manage_menu_screen.dart';
import 'package:ilgabbiano/screens/admin/manage_reservations_screen.dart';
import 'package:ilgabbiano/screens/admin/manage_users_screen.dart';
import 'package:ilgabbiano/screens/admin/view_complaints_screen.dart';
import 'package:ilgabbiano/screens/admin/view_feedbacks_screen.dart';
import 'package:ilgabbiano/screens/admin/view_orders_screen.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/screens/auth/login_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../l10n/strings.dart';

class AdminHomeScreen extends StatelessWidget {
  final SessionManager _sessionManager = SessionManager();

  void _logout(BuildContext context) async {
    await _sessionManager.clearSession();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDashboardItem(context, 'Gérer le Menu', Icons.restaurant_menu, ManageMenuScreen()),
          _buildDashboardItem(context, 'Gérer les Réservations', Icons.book_online, ManageReservationsScreen()),
          _buildDashboardItem(context, 'Gérer les Utilisateurs', Icons.people, ManageUsersScreen()),
          _buildDashboardItem(context, Strings.ordersTitle, Icons.receipt, ViewOrdersScreen()),
          _buildDashboardItem(context, 'Voir les Avis', Icons.feedback, ViewFeedbacksScreen()),
          _buildDashboardItem(context, 'Voir les Réclamations', Icons.report_problem, ViewComplaintsScreen()),
        ].animate(interval: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.5),
      ),
    );
  }

  Widget _buildDashboardItem(BuildContext context, String title, IconData icon, Widget screen) {
    return Card(
      elevation: 4.0,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50.0, color: Theme.of(context).primaryColor),
            SizedBox(height: 10.0),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
