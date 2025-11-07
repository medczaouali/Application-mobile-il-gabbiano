import 'dart:ui';
import 'dart:math' as math;
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
import 'package:google_fonts/google_fonts.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../db/database_helper.dart';
import '../../l10n/strings.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final SessionManager _sessionManager = SessionManager();
  final DatabaseHelper _db = DatabaseHelper();

  int _pendingReservations = 0;
  int _pendingOrders = 0;
  int _pendingComplaints = 0;
  double _avgRating = 0.0;
  int _reviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await Future.wait([
        _db.countPendingReservations(),
        _db.countPendingOrders(),
        _db.countPendingComplaints(),
        _db.getFeedbackAverage(),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingReservations = counts[0] as int;
        _pendingOrders = counts[1] as int;
        _pendingComplaints = counts[2] as int;
        final avg = counts[3] as Map<String, dynamic>;
        _avgRating = ((avg['average'] as double?) ?? 0.0).isNaN ? 0.0 : (avg['average'] as double? ?? 0.0);
        _reviewsCount = (avg['count'] as int?) ?? 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

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
      body: RefreshIndicator(
        onRefresh: _loadCounts,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              floating: false,
              elevation: 0,
              expandedHeight: 260,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Rafraîchir',
                  onPressed: _loadCounts,
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _logout(context),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(context),
              ),
            ),
            SliverToBoxAdapter(child: _buildQuickActions(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildListDelegate([
                  _buildActionCard(
                    context,
                    title: 'Gérer le Menu',
                    icon: Icons.restaurant_menu,
                    colors: BrandPalette.menuGradient,
                    onTap: () async { await _open(context, ManageMenuScreen()); },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Gérer les Réservations',
                    icon: Icons.book_online,
                    badge: _pendingReservations,
                    colors: BrandPalette.reservationsGradient,
                    onTap: () async { await _open(context, ManageReservationsScreen()); },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Gérer les Utilisateurs',
                    icon: Icons.people,
                    colors: BrandPalette.usersGradient,
                    onTap: () async { await _open(context, ManageUsersScreen()); },
                  ),
                  _buildActionCard(
                    context,
                    title: Strings.ordersTitle,
                    icon: Icons.receipt_long,
                    badge: _pendingOrders,
                    colors: BrandPalette.ordersGradient,
                    onTap: () async { await _open(context, ViewOrdersScreen()); },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Voir les Avis',
                    icon: Icons.feedback,
                    colors: BrandPalette.reviewsGradient,
                    onTap: () async { await _open(context, ViewFeedbacksScreen()); },
                  ),
                  _buildActionCard(
                    context,
                    title: 'Voir les Réclamations',
                    icon: Icons.report_problem,
                    badge: _pendingComplaints,
                    colors: BrandPalette.complaintsGradient,
                    onTap: () async { await _open(context, ViewComplaintsScreen()); },
                  ),
                ].animate(interval: 80.ms).fadeIn(duration: 300.ms).slideY(begin: 0.3)),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
    _loadCounts();
  }

  Widget _buildHeader(BuildContext context) {
    final ratingStr = (_avgRating.isNaN ? 0.0 : _avgRating).toStringAsFixed(1);
    final today = DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now());
    // Simple placeholder trends (last point equals current value)
    final reservationsTrend = [2.0, 3.0, 2.5, 4.0, 3.5, 5.0, _pendingReservations.toDouble()];
    final ordersTrend = [1.0, 2.0, 1.5, 2.5, 3.0, 2.0, _pendingOrders.toDouble()];
    final complaintsTrend = [4.0, 3.0, 3.5, 2.5, 2.0, 2.2, _pendingComplaints.toDouble()];
    final ratingTrend = [3.5, 3.8, 4.0, 4.2, 4.1, 4.3, _avgRating.isNaN ? 0.0 : _avgRating];
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: BrandPalette.headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bienvenue 👋', style: GoogleFonts.lato(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Tableau de bord', style: GoogleFonts.lato(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(today, style: GoogleFonts.lato(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Take remaining space to avoid overflow
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _GlassStatCard(
                          icon: Icons.book_online,
                          label: 'Réservations',
                          value: _pendingReservations,
                          subtitle: 'en attente',
                          trend: reservationsTrend,
                        ),
                        _GlassStatCard(
                          icon: Icons.receipt_long,
                          label: 'Commandes',
                          value: _pendingOrders,
                          subtitle: 'en attente',
                          trend: ordersTrend,
                        ),
                        _GlassStatCard(
                          icon: Icons.report_problem,
                          label: 'Réclamations',
                          value: _pendingComplaints,
                          subtitle: 'ouvertes',
                          trend: complaintsTrend,
                        ),
                        _GlassRatingCard(avg: ratingStr, count: _reviewsCount, trend: ratingTrend),
                        const SizedBox(width: 4),
                      ].animate(interval: 80.ms).fadeIn(duration: 300.ms).slideX(begin: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions rapides', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _QuickActionChip(
                  icon: Icons.add,
                  label: 'Nouveau plat',
                  onTap: () => _open(context, ManageMenuScreen()),
                ),
                _QuickActionChip(
                  icon: Icons.event_available,
                  label: 'Nouvelle réservation',
                  onTap: () => _open(context, ManageReservationsScreen()),
                ),
                _QuickActionChip(
                  icon: Icons.person_add,
                  label: 'Inviter admin',
                  onTap: () => _open(context, ManageUsersScreen()),
                ),
                _QuickActionChip(
                  icon: Icons.feedback,
                  label: 'Voir les avis',
                  onTap: () => _open(context, ViewFeedbacksScreen()),
                ),
                _QuickActionChip(
                  icon: Icons.report_problem,
                  label: 'Réclamations',
                  onTap: () => _open(context, ViewComplaintsScreen()),
                ),
              ].animate(interval: 60.ms).fadeIn(duration: 250.ms).slideX(begin: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Color> colors,
    int? badge,
    required VoidCallback onTap,
  }) {
    final count = (badge ?? 0);
    final hasBadge = count > 0;
    final display = count > 99 ? '99+' : '$count';
    return _ScaleTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: BrandPalette.softShadow,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: BrandPalette.glassOnPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.lato(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (hasBadge)
              Positioned(
                right: 12,
                top: 12,
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
        ),
      ),
    );
  }
}

// Removed old chip widgets in favor of modern glass cards and quick action chips.

class _GlassStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String subtitle;
  final List<double>? trend;
  const _GlassStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final display = value > 999 ? '999+' : '$value';
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                if (trend != null) Positioned.fill(child: _MiniSparkline(data: trend!)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white),
                        ),
                        const Spacer(),
                        Container(
                          height: 8,
                          width: 8,
                          decoration: const BoxDecoration(color: Colors.lightGreenAccent, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    Text(display, style: GoogleFonts.lato(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    Row(
                      children: [
                        Text(label, style: GoogleFonts.lato(color: Colors.white70)),
                        const SizedBox(width: 8),
                        Text('• $subtitle', style: GoogleFonts.lato(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassRatingCard extends StatelessWidget {
  final String avg;
  final int count;
  final List<double>? trend;
  const _GlassRatingCard({required this.avg, required this.count, this.trend});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                if (trend != null) Positioned.fill(child: _MiniSparkline(data: trend!)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, color: Colors.yellowAccent),
                        ),
                        const Spacer(),
                        Container(
                          height: 8,
                          width: 8,
                          decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(avg, style: GoogleFonts.lato(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 6),
                        Text('/5', style: GoogleFonts.lato(color: Colors.white70)),
                      ],
                    ),
                    Text('($count avis)', style: GoogleFonts.lato(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<double> data;
  const _MiniSparkline({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final minY = data.reduce(math.min);
    final maxY = data.reduce(math.max);
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: minY - (maxY - minY) * 0.2,
            maxY: maxY + (maxY - minY) * 0.2,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                barWidth: 2,
                color: Colors.white.withValues(alpha: 0.9),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                spots: [
                  for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i])
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _ScaleTap({required this.child, this.onTap});

  @override
  State<_ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<_ScaleTap> {
  double _scale = 1.0;

  void _down(_) => setState(() => _scale = 0.98);
  void _up(_) => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: _up,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
