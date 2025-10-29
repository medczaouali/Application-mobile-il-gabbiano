import 'package:flutter/material.dart';
import 'package:ilgabbiano/screens/client/client_menu_screen.dart';
import 'package:ilgabbiano/screens/client/feedback_screen.dart';
import 'package:ilgabbiano/screens/client/order_history_screen.dart';
import 'package:ilgabbiano/screens/client/profile_screen.dart';
import 'package:ilgabbiano/screens/client/reservation_screen.dart';
import 'package:ilgabbiano/screens/client/reservation_history_screen.dart';
import 'package:ilgabbiano/screens/client/complaint_history_screen.dart';
import 'package:ilgabbiano/screens/common/restaurant_info_screen.dart';
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

class ClientHomeScreen extends StatelessWidget {
  final SessionManager _sessionManager = SessionManager();

  void _logout(BuildContext context) async {
    await _sessionManager.clearSession();
    // Reset unread provider and stop realtime polling when logging out
    try {
      final up = Provider.of<UnreadProvider>(context, listen: false);
      up.reset();
    } catch (e) {}
    try {
      RealtimeService().stop();
    } catch (e) {}
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('app_title')),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Builder(builder: (scaffoldCtx) {
        // Use a Stack so we can keep the GridView as the main content
        // and use a Consumer to show/remove a persistent MaterialBanner
        // via the ScaffoldMessenger. The banner stays until the user
        // opens the complaints screen (which will clear unread counts).
        return Stack(
          children: [
            GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildDashboardItem(context, AppLocalizations.of(context).t('menu'), Icons.restaurant_menu, ClientMenuScreen()),
                _buildDashboardItem(context, AppLocalizations.of(context).t('reserve'), Icons.book_online, ReservationScreen()),
                _buildDashboardItem(context, AppLocalizations.of(context).t('my_reservations'), Icons.event_note, ReservationHistoryScreen()),
                _buildDashboardItem(context, AppLocalizations.of(context).t('my_orders'), Icons.history, OrderHistoryScreen()),
                _buildDashboardItem(context, AppLocalizations.of(context).t('feedback'), Icons.feedback, FeedbackScreen()),
                _buildDashboardItem(context, AppLocalizations.of(context).t('complaints'), Icons.report_problem, ComplaintHistoryScreen()),
              ].animate(interval: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.5),
            ),

            // Invisible builder used to manage the persistent banner. We avoid
            // using Consumer directly because Provider may be added in main and
            // a hot-reload could leave this context without the provider and
            // crash. Instead, attempt Provider.of in a try/catch and fall back
            // to the global UnreadProvider.instance.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Builder(builder: (ctx) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    UnreadProvider? up;
                    try {
                      up = Provider.of<UnreadProvider>(ctx, listen: true);
                    } catch (_) {
                      up = UnreadProvider.instance;
                    }
                    if (up == null) return;
                    final messenger = ScaffoldMessenger.of(scaffoldCtx);
                    if (up.totalUnread > 0) {
                      messenger.showMaterialBanner(
                        MaterialBanner(
                          content: Text('${up.totalUnread} nouvelle(s) réponse(s) à vos réclamations'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                messenger.hideCurrentMaterialBanner();
                                // Close drawer if open, then open complaint history
                                try {
                                  Navigator.of(scaffoldCtx).pop();
                                } catch (e) {
                                  // ignore if no drawer open
                                }
                                Navigator.of(scaffoldCtx).push(MaterialPageRoute(builder: (_) => ComplaintHistoryScreen()));
                              },
                              child: Text(AppLocalizations.of(scaffoldCtx).t('view')),
                            ),
                          ],
                        ),
                      );
                    } else {
                      messenger.removeCurrentMaterialBanner();
                    }
                  } catch (e) {
                    // If provider isn't ready or scaffold context invalid, ignore.
                  }
                });
                return const SizedBox.shrink();
              }),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final db = DatabaseHelper();
    return Drawer(
      child: FutureBuilder<Map<String, dynamic>?>(
        future: SessionManager().getUserSession(),
        builder: (context, sessSnap) {
          if (sessSnap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
          final session = sessSnap.data;
          return FutureBuilder(
            future: session != null ? db.getUserById(session['id']) : Future.value(null),
            builder: (context, userSnap) {
              final user = userSnap.data as dynamic;
              return Column(
                children: [
                  // Animated header
                  Animate(
                    effects: [
                      const SlideEffect(begin: Offset(-0.2, 0), end: Offset.zero, duration: Duration(milliseconds: 360)),
                      const FadeEffect(duration: Duration(milliseconds: 360)),
                    ],
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            backgroundImage: user != null && user.profileImage != null ? FileImage(File(user.profileImage)) : null,
                            child: user == null || user.profileImage == null ? Icon(Icons.person, size: 32, color: Theme.of(context).colorScheme.onPrimary) : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(user?.name ?? AppLocalizations.of(context).t('profile'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                                const SizedBox(height: 4),
                                  Text(user?.email ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.9))),
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
                            effects: [FadeEffect(delay: Duration(milliseconds: 60))],
                            child: Text(AppLocalizations.of(context).t('profile'), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                          ),
                        ),
                        Animate(
                          effects: [SlideEffect(begin: Offset(-0.1, 0), end: Offset.zero, duration: Duration(milliseconds: 260)), FadeEffect(duration: Duration(milliseconds: 260))],
                          child: ListTile(
                            leading: Icon(Icons.person_outline),
                            title: Text(AppLocalizations.of(context).t('profile')),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
                            },
                          ),
                        ),
                        Animate(
                          effects: [SlideEffect(begin: Offset(-0.08, 0), end: Offset.zero, duration: Duration(milliseconds: 280)), FadeEffect(duration: Duration(milliseconds: 280))],
                          child: ListTile(
                            leading: Icon(Icons.history),
                            title: Text(AppLocalizations.of(context).t('my_orders')),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (context) => OrderHistoryScreen()));
                            },
                          ),
                        ),
                        Animate(
                          effects: [SlideEffect(begin: Offset(-0.06, 0), end: Offset.zero, duration: Duration(milliseconds: 300)), FadeEffect(duration: Duration(milliseconds: 300))],
                          child: ListTile(
                            leading: Icon(Icons.event_note),
                            title: Text(AppLocalizations.of(context).t('reserve')),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ReservationHistoryScreen()));
                            },
                          ),
                        ),
                        Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Animate(effects: [FadeEffect(), SlideEffect(begin: Offset(-0.1, 0), end: Offset.zero)], child: Text(AppLocalizations.of(context).t('support'), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54))),
                        ),
                                      Animate(
                                        effects: [SlideEffect(begin: Offset(-0.08, 0), end: Offset.zero), FadeEffect()],
                                        child: Builder(builder: (ctx) {
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
                                            title: Text(AppLocalizations.of(context).t('complaints')),
                                            trailing: total > 0
                                                ? Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                                                    child: Text('$total', style: TextStyle(color: Colors.white, fontSize: 12)),
                                                  )
                                                : null,
                                            onTap: () {
                                              Navigator.pop(context);
                                              Navigator.push(context, MaterialPageRoute(builder: (context) => ComplaintHistoryScreen()));
                                            },
                                          );
                                        }),
                                      ),
                        Animate(effects: [SlideEffect(begin: Offset(-0.06, 0), end: Offset.zero), FadeEffect()], child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text(AppLocalizations.of(context).t('restaurant_info')),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const RestaurantInfoScreen()));
                          },
                        )),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.logout),
                                label: Text(AppLocalizations.of(context).t('logout')),
                                onPressed: () => _logout(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _LanguagePicker(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
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
            child: Text(AppLocalizations.of(context).t('language'), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
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
