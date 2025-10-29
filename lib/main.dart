import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ilgabbiano/providers/cart_provider.dart';
import 'package:ilgabbiano/screens/admin/admin_home_screen.dart';
import 'package:ilgabbiano/screens/auth/login_screen.dart';
import 'package:ilgabbiano/screens/client/client_home_screen.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:ilgabbiano/providers/locale_provider.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:ilgabbiano/services/realtime_service.dart';
import 'package:ilgabbiano/screens/admin/complaint_detail_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  final sessionManager = SessionManager();
  final session = await sessionManager.getUserSession();
  final navigatorKey = GlobalKey<NavigatorState>();

  // run preflight migrations synchronously before building UI
  await _ensurePreflightMigrations();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        Provider(create: (_) => sessionManager),
        ChangeNotifierProvider(create: (_) => UnreadProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: MyApp(session: session, navigatorKey: navigatorKey),
    ),
  );
}

// Ensure schema migrations that must run before any UI/database access
// are executed here in main() so no widget tries to query `is_read` before
// the column has been added.
Future<void> _ensurePreflightMigrations() async {
  try {
    await DatabaseHelper().ensureComplaintMessagesSchema();
  } catch (e) {
    // ignore
  }
}

class MyApp extends StatefulWidget {
  final Map<String, dynamic>? session;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MyApp({Key? key, this.session, this.navigatorKey}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    if (widget.session != null) {
      // Schedule async initialization after the widget is mounted to avoid
      // calling async APIs directly from initState.
      Future.microtask(() async {
        final userId = widget.session!['id'];
        Provider.of<CartProvider>(context, listen: false).init(userId);
        // Ensure DB schema is ready (adds is_read if missing) before starting realtime
        try {
          await DatabaseHelper().ensureComplaintMessagesSchema();
        } catch (e) {}
        // initialize unread provider (safe: fall back to global instance)
        try {
          try {
            await Provider.of<UnreadProvider>(context, listen: false).init(userId);
          } catch (_) {
            await UnreadProvider.instance?.init(userId);
          }
        } catch (e) {}
        // start realtime polling
        RealtimeService().start(userId);
        _realtimeSub = RealtimeService().stream.listen((event) {
          // forward event to unread provider so UI badges update. We try the
          // Provider first, but fall back to the global instance if Provider
          // lookup fails (early startup timing).
          try {
            try {
              Provider.of<UnreadProvider>(context, listen: false).onRealtimeEvent(event);
            } catch (_) {
              UnreadProvider.instance?.onRealtimeEvent(event);
            }
          } catch (_) {}
          // show an in-app notification with action to open the complaint
          final nav = widget.navigatorKey?.currentState;
          if (nav != null) {
            final ctx = nav.context;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('Nouvelle réponse à la réclamation #${event['complaintId']} (${event['unread']})'),
                action: SnackBarAction(
                  label: 'Ouvrir',
                  onPressed: () {
                    // navigate to complaint detail
                    final id = event['complaintId'];
                    if (id != null) {
                      nav.push(MaterialPageRoute(builder: (_) => ComplaintDetailScreen(complaint: {'id': id, 'user_name': 'Utilisateur', 'message': '', 'status': 'pending'})));
                    }
                  },
                ),
              ),
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    RealtimeService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    return MaterialApp(
      title: 'Il Gabbiano',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: widget.navigatorKey,
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('it'),
        Locale('es'),
        Locale('de'),
        Locale('pt'),
        Locale('ar'),
      ],
      localizationsDelegates: [
        const AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    if (widget.session != null) {
      if (widget.session!['role'] == 'admin') {
        return AdminHomeScreen();
      } else {
        return ClientHomeScreen();
      }
    }
    return LoginScreen();
  }
}
