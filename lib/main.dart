import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ilgabbiano/providers/cart_provider.dart';
import 'package:ilgabbiano/screens/admin/admin_home_screen.dart';
import 'package:ilgabbiano/screens/auth/login_screen.dart';
import 'package:ilgabbiano/screens/client/client_home_screen.dart';
import 'package:ilgabbiano/services/session_manager.dart';
import 'package:ilgabbiano/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:ilgabbiano/providers/locale_provider.dart';
import 'package:ilgabbiano/providers/unread_provider.dart';
import 'package:ilgabbiano/providers/theme_provider.dart';
import 'package:ilgabbiano/providers/biometric_provider.dart';
import 'package:ilgabbiano/db/database_helper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ilgabbiano/localization/app_localizations.dart';
import 'package:ilgabbiano/services/realtime_service.dart';
import 'package:ilgabbiano/screens/admin/complaint_detail_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/auth/biometric_lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('fr_FR', null);
  // Initialize Supabase (password reset via link/OTP)
  try {
    await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
  } catch (e) {
    // If not configured yet, ignore (app still works with local auth)
  }
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => BiometricProvider()..init()),
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

  const MyApp({super.key, this.session, this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _realtimeSub;
  StreamSubscription<AuthState>? _sbAuthSub;

  @override
  void initState() {
    super.initState();
    // Listen for Supabase password recovery deep-link events
    try {
      _sbAuthSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.passwordRecovery) {
          final nav = widget.navigatorKey?.currentState;
          if (nav != null) {
            nav.push(MaterialPageRoute(builder: (_) => ResetPasswordScreen()));
          }
        }
      });
    } catch (_) {}
    if (widget.session != null) {
      // Schedule async initialization after the widget is mounted to avoid
      // calling async APIs directly from initState.
      Future.microtask(() async {
        final userId = widget.session!['id'];
        Provider.of<CartProvider>(context, listen: false).init(userId);
        // Ensure DB schema is ready (adds is_read if missing) before starting realtime
        try {
          await DatabaseHelper().ensureComplaintMessagesSchema();
        } catch (e) {
          // Schema may be already migrated; ignore.
        }
        // initialize unread provider (safe: fall back to global instance)
        try {
          try {
            await Provider.of<UnreadProvider>(context, listen: false).init(userId);
          } catch (_) {
            await UnreadProvider.instance?.init(userId);
          }
        } catch (e) {
          // Unread provider initialization may fail early; ignore.
        }
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
    _sbAuthSub?.cancel();
    RealtimeService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, ThemeProvider>(
      builder: (context, localeProvider, themeProvider, child) {
        return MaterialApp(
          title: 'Il Gabbiano',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
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
      },
    );
  }

  Widget _getInitialScreen() {
    if (widget.session != null) {
      final role = widget.session!['role'];
      final next = role == 'admin' ? AdminHomeScreen() : ClientHomeScreen();
      // If biometric lock is enabled and available, gate with lock screen
      final bio = Provider.of<BiometricProvider>(context, listen: false);
      if (bio.initialized && bio.available && bio.enabled) {
        return BiometricLockScreen(next: next);
      }
      return next;
    }
    return LoginScreen();
  }
}

// Minimal screen to set a new password after Supabase recovery link
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwd = TextEditingController();
  bool _loading = false;

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _pwd.text.trim()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mot de passe mis à jour.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nouveau mot de passe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _pwd,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (v) => v == null || v.length < 6 ? 'Au moins 6 caractères' : null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _update,
                  icon: _loading ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.lock_reset),
                  label: Text('Mettre à jour'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
