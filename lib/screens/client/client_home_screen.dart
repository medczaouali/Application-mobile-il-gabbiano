import 'package:flutter/material.dart';
import 'package:ilgabbiano/screens/client/client_menu_screen.dart';
import 'package:ilgabbiano/screens/client/feedback_screen.dart';
import 'package:ilgabbiano/screens/client/order_history_screen.dart';
import 'package:ilgabbiano/screens/client/profile_screen.dart';
import 'package:ilgabbiano/screens/client/reservation_screen.dart';
import 'package:ilgabbiano/screens/client/reservation_history_screen.dart';
import 'package:ilgabbiano/screens/client/complaint_history_screen.dart';
import 'package:ilgabbiano/screens/common/restaurant_info_screen.dart';
import 'package:ilgabbiano/screens/client/settings_screen.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ilgabbiano/providers/locale_provider.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';
import 'package:ilgabbiano/services/realtime_service.dart';
import '../../db/database_helper.dart';
import 'dart:io';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/screens/auth/login_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ilgabbiano/theme/brand_palette.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import 'dart:math' as math;

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});
  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final SessionManager _sessionManager = SessionManager();
  final DatabaseHelper _db = DatabaseHelper();

  int _myReservations = 0;
  int _myOrders = 0;
  int _unread = 0;
  double _myRating = 0.0;

  void _logout(BuildContext context) async {
    await _sessionManager.clearSession();
    // Reset unread provider and stop realtime polling when logging out
    try {
      final up = Provider.of<UnreadProvider>(context, listen: false);
      up.reset();
    } catch (e) {
      // Provider may be unavailable during logout navigation; ignore.
    }
    try {
      RealtimeService().stop();
    } catch (e) {
      // Realtime service might not be started; ignore.
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sess = await _sessionManager.getUserSession();
      final id = sess?['id'] as int?;
      if (id == null) return;
      final results = await Future.wait([
        _db.getUserReservations(id),
        _db.getOrdersByUser(id),
        _db.getFeedbackByUser(id),
      ]);
      if (!mounted) return;
      setState(() {
        _myReservations = (results[0] as List).length;
        _myOrders = (results[1] as List).length;
        final fb = results[2];
        _myRating = fb != null ? ((fb as dynamic).rating as num).toDouble() : 0.0;
        try {
          _unread = Provider.of<UnreadProvider>(context, listen: false).totalUnread;
        } catch (_) {
          _unread = 0;
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    try { _unread = Provider.of<UnreadProvider>(context).totalUnread; } catch (_) {}
    return Scaffold(
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              expandedHeight: 260,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: true,
              actions: [
                IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
              ],
              flexibleSpace: FlexibleSpaceBar(background: _buildHeader(context)),
            ),
            SliverToBoxAdapter(child: _buildQuickActions(context)),
            SliverToBoxAdapter(
              child: Builder(
                builder: (ctx) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      UnreadProvider? up;
                      try {
                        up = Provider.of<UnreadProvider>(ctx, listen: true);
                      } catch (_) {
                        up = UnreadProvider.instance;
                      }
                      if (up == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      if (up.totalUnread > 0) {
                        messenger.showMaterialBanner(MaterialBanner(
                          content: Text('${up.totalUnread} nouvelle(s) réponse(s) à vos réclamations'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                messenger.hideCurrentMaterialBanner();
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComplaintHistoryScreen()));
                              },
                              child: Text(AppLocalizations.of(context).t('view')),
                            ),
                          ],
                        ));
                      } else {
                        messenger.removeCurrentMaterialBanner();
                      }
                    } catch (_) {}
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildListDelegate([
                  _buildActionCard(
                    context,
                    title: AppLocalizations.of(context).t('menu'),
                    icon: Icons.restaurant_menu,
                    colors: BrandPalette.menuGradient,
                    onTap: () => _open(context, ClientMenuScreen()),
                  ),
                  _buildActionCard(
                    context,
                    title: AppLocalizations.of(context).t('reserve'),
                    icon: Icons.book_online,
                    colors: BrandPalette.reservationsGradient,
                    onTap: () => _open(context, ReservationScreen()),
                  ),
                  _buildActionCard(
                    context,
                    title: AppLocalizations.of(context).t('my_reservations'),
                    icon: Icons.event_note,
                    badge: _myReservations,
                    colors: BrandPalette.ordersGradient,
                    onTap: () => _open(context, ReservationHistoryScreen()),
                  ),
                  _buildActionCard(
                    context,
                    title: AppLocalizations.of(context).t('my_orders'),
                    icon: Icons.history,
                    badge: _myOrders,
                    colors: BrandPalette.reviewsGradient,
                    onTap: () => _open(context, OrderHistoryScreen()),
                  ),
                  _buildActionCard(
                    context,
                    title: AppLocalizations.of(context).t('feedback'),
                    icon: Icons.feedback,
                    colors: BrandPalette.reviewsGradient,
                    onTap: () => _open(context, FeedbackScreen()),
                  ),
                  _buildActionCard(
                    context,
                    title: AppLocalizations.of(context).t('complaints'),
                    icon: Icons.report_problem,
                    badge: _unread,
                    colors: BrandPalette.complaintsGradient,
                    onTap: () => _open(context, ComplaintHistoryScreen()),
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

  Widget _buildDrawer(BuildContext context) {
    final db = DatabaseHelper();
    return Drawer(
      child: SafeArea(
        // Ensure drawer content stays clear of status/navigation bars on all devices
        child: FutureBuilder<Map<String, dynamic>?>(
        future: SessionManager().getUserSession(),
        builder: (context, sessSnap) {
          if (sessSnap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          final session = sessSnap.data;
          return FutureBuilder(
            future: session != null
                ? db.getUserById(session['id'])
                : Future.value(null),
            builder: (context, userSnap) {
              final user = userSnap.data as dynamic;
              return Column(
                children: [
                  // Animated header
                  Animate(
                    effects: [
                      const SlideEffect(
                        begin: Offset(-0.2, 0),
                        end: Offset.zero,
                        duration: Duration(milliseconds: 360),
                      ),
                      const FadeEffect(duration: Duration(milliseconds: 360)),
                    ],
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            backgroundImage:
                                user != null && user.profileImage != null
                                ? FileImage(File(user.profileImage))
                                : null,
                            child: user == null || user.profileImage == null
                                ? Icon(
                                    Icons.person,
                                    size: 32,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  )
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ??
                                      AppLocalizations.of(context).t('profile'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ?? '',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Animate(
                            effects: [
                              FadeEffect(delay: Duration(milliseconds: 60)),
                            ],
                            child: Text(
                              AppLocalizations.of(context).t('profile'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        Animate(
                          effects: [
                            SlideEffect(
                              begin: Offset(-0.1, 0),
                              end: Offset.zero,
                              duration: Duration(milliseconds: 260),
                            ),
                            FadeEffect(duration: Duration(milliseconds: 260)),
                          ],
                          child: ListTile(
                            leading: Icon(Icons.person_outline),
                            title: Text(
                              AppLocalizations.of(context).t('profile'),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Animate(
                          effects: [
                            SlideEffect(
                              begin: Offset(-0.08, 0),
                              end: Offset.zero,
                              duration: Duration(milliseconds: 280),
                            ),
                            FadeEffect(duration: Duration(milliseconds: 280)),
                          ],
                          child: ListTile(
                            leading: Icon(Icons.history),
                            title: Text(
                              AppLocalizations.of(context).t('my_orders'),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderHistoryScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Animate(
                          effects: [
                            SlideEffect(
                              begin: Offset(-0.06, 0),
                              end: Offset.zero,
                              duration: Duration(milliseconds: 300),
                            ),
                            FadeEffect(duration: Duration(milliseconds: 300)),
                          ],
                          child: ListTile(
                            leading: Icon(Icons.event_note),
                            title: Text(
                              AppLocalizations.of(context).t('reserve'),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ReservationHistoryScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Animate(
                            effects: [
                              FadeEffect(),
                              SlideEffect(
                                begin: Offset(-0.1, 0),
                                end: Offset.zero,
                              ),
                            ],
                            child: Text(
                              AppLocalizations.of(context).t('support'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                        Animate(
                          effects: [
                            SlideEffect(
                              begin: Offset(-0.08, 0),
                              end: Offset.zero,
                            ),
                            FadeEffect(),
                          ],
                          child: Builder(
                            builder: (ctx) {
                              // Safely attempt to read UnreadProvider; if it's not available
                              // (for example during early startup), fall back to 0.
                              int total = 0;
                              try {
                                final up = Provider.of<UnreadProvider>(ctx);
                                total = up.totalUnread;
                              } catch (e) {
                                // provider not available yet - ignore and show no badge
                              }
                              return ListTile(
                                leading: Icon(Icons.report_problem_outlined),
                                title: Text(
                                  AppLocalizations.of(context).t('complaints'),
                                ),
                                trailing: total > 0
                                    ? Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '$total',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ComplaintHistoryScreen(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Animate(
                          effects: [
                            SlideEffect(
                              begin: Offset(-0.06, 0),
                              end: Offset.zero,
                            ),
                            FadeEffect(),
                          ],
                          child: ListTile(
                            leading: Icon(Icons.info_outline),
                            title: Text(
                              AppLocalizations.of(context).t('restaurant_info'),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RestaurantInfoScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(
                      left: 12.0,
                      right: 12.0,
                      top: 6.0,
                      // Add bottom safe area so buttons are above the gesture bar / nav keys
                      bottom: 6.0 + MediaQuery.of(context).padding.bottom + 8.0,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.settings),
                                label: Text(
                                  AppLocalizations.of(context).t('settings'),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SettingsScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.logout),
                                label: Text(
                                  AppLocalizations.of(context).t('logout'),
                                ),
                                onPressed: () => _logout(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
  }

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
    _load();
  }

  Widget _buildHeader(BuildContext context) {
    final appTitle = AppLocalizations.of(context).t('app_title');
    final resTrend = [1.0, 1.5, 2.0, 1.8, 2.5, 3.0, _myReservations.toDouble()];
    final ordersTrend = [0.5, 1.0, 1.2, 1.0, 1.6, 2.0, _myOrders.toDouble()];
    final unreadTrend = [0.0, 0.0, 1.0, 2.0, 1.0, 1.5, _unread.toDouble()];
    final myRatingTrend = [3.5, 3.6, 3.7, 3.9, 4.0, 4.2, _myRating];
    return Container(
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
              Text(appTitle, style: GoogleFonts.lato(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(AppLocalizations.of(context).t('welcome'), style: GoogleFonts.lato(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _GlassStatCard(icon: Icons.event_note, label: AppLocalizations.of(context).t('my_reservations'), value: _myReservations, subtitle: AppLocalizations.of(context).t('total'), trend: resTrend),
                    _GlassStatCard(icon: Icons.history, label: AppLocalizations.of(context).t('my_orders'), value: _myOrders, subtitle: AppLocalizations.of(context).t('total'), trend: ordersTrend),
                    _GlassStatCard(icon: Icons.mark_chat_unread, label: AppLocalizations.of(context).t('complaints'), value: _unread, subtitle: AppLocalizations.of(context).t('unread'), trend: unreadTrend),
                    _GlassRatingCard(avg: _myRating.toStringAsFixed(1), count: _myRating > 0 ? 1 : 0, trend: myRatingTrend),
                  ].animate(interval: 80.ms).fadeIn(duration: 300.ms).slideX(begin: 0.2),
                ),
              ),
            ],
          ),
        ),
      ),
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
                _QuickActionChip(icon: Icons.restaurant, label: AppLocalizations.of(context).t('menu'), onTap: () => _open(context, ClientMenuScreen())),
                _QuickActionChip(icon: Icons.book_online, label: AppLocalizations.of(context).t('reserve'), onTap: () => _open(context, ReservationScreen())),
                _QuickActionChip(icon: Icons.person_outline, label: AppLocalizations.of(context).t('profile'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()))),
                _QuickActionChip(icon: Icons.settings, label: AppLocalizations.of(context).t('settings'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()))),
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
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
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
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  Text(title, style: GoogleFonts.lato(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (hasBadge)
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 18),
                  child: Center(child: Text(display, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String subtitle;
  final List<double>? trend;
  const _GlassStatCard({required this.icon, required this.label, required this.value, required this.subtitle, this.trend});

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
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: Icon(icon, color: Colors.white),
                        ),
                        const Spacer(),
                        Container(height: 8, width: 8, decoration: const BoxDecoration(color: Colors.lightGreenAccent, shape: BoxShape.circle)),
                      ],
                    ),
                    Text(display, style: GoogleFonts.lato(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    Row(children: [
                      Text(label, style: GoogleFonts.lato(color: Colors.white70)),
                      const SizedBox(width: 8),
                      Text('• $subtitle', style: GoogleFonts.lato(color: Colors.white70)),
                    ]),
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
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.star, color: Colors.yellowAccent),
                        ),
                        const Spacer(),
                        Container(height: 8, width: 8, decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle)),
                      ],
                    ),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(avg, style: GoogleFonts.lato(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Text('/5', style: GoogleFonts.lato(color: Colors.white70)),
                    ]),
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
          ]),
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
                belowBarData: BarAreaData(show: true, color: Colors.white.withValues(alpha: 0.15)),
                spots: [for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i])],
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

class _LanguagePicker extends StatefulWidget {
  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  final List<Map<String, String>> _langs = [
    {'code': 'fr', 'label': 'Français'},
    {'code': 'it', 'label': 'Italiano'},
    {'code': 'en', 'label': 'English'},
    {'code': 'ar', 'label': 'العربية'},
    {'code': 'es', 'label': 'Español'},
    {'code': 'de', 'label': 'Deutsch'},
    {'code': 'pt', 'label': 'Português'},
  ];

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final current = localeProvider.locale.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6),
            child: Text(
              AppLocalizations.of(context).t('language'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: _langs.map((l) {
            final code = l['code']!;
            final label = l['label']!;
            final selected = code == current;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (v) async {
                if (v) {
                  await localeProvider.setLocale(Locale(code));
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
