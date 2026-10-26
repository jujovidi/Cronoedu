import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'models/account.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell.dart';
import 'services/auth_repository.dart';
import 'services/leaderboard_repository.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_repositories.dart';
import 'state/auth_controller.dart';
import 'state/app_state.dart';
import 'state/study_timer.dart';
import 'theme/app_theme.dart';

/// Proyecto de Supabase. Se pasan al compilar (en VS Code, la configuración
/// "CronoEdu (Supabase)" ya lo hace):
///   flutter run --dart-define-from-file=supabase/app_config.json
/// Sin ellos, las cuentas y el ranking quedan solo en el celular.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  final prefs = await SharedPreferences.getInstance();
  final AuthController auth;
  if (_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty) {
    final client = (await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey)).client;
    auth = AuthController(
      SupabaseAuthRepository(client),
      SupabaseLeaderboardRepository(client),
      bellotas: SupabaseBellotasRepository(client),
    );
  } else {
    auth = AuthController(LocalAuthRepository(prefs), LocalLeaderboardRepository(prefs));
  }
  await NotificationService.instance.init();
  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: CronoEduRoot(prefs: prefs),
    ),
  );
}

/// Sin sesión muestra el inicio de sesión; con sesión, la app de esa cuenta.
class CronoEduRoot extends StatelessWidget {
  const CronoEduRoot({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final account = context.select<AuthController, Account?>((a) => a.account);
    if (account == null) return const AuthApp();
    return UserSession(key: ValueKey(account.id), account: account, prefs: prefs);
  }
}

/// Crea el estado de la cuenta (tareas, horario, perfil y temporizador) y lo
/// libera al cerrar sesión.
class UserSession extends StatefulWidget {
  const UserSession({super.key, required this.account, required this.prefs});
  final Account account;
  final SharedPreferences prefs;

  @override
  State<UserSession> createState() => _UserSessionState();
}

class _UserSessionState extends State<UserSession> {
  late final AppState _state;
  late final StudyTimer _timer;
  VoidCallback? _stopSync;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _state = AppState(
      StorageService(widget.prefs, namespace: widget.account.id),
      account: widget.account,
      leaderboard: auth.leaderboard,
      bellotasServer: auth.bellotas,
    );
    _timer = StudyTimer(
      onCycleCompleted: (t) => _state.addCycle(pomodoro: t == Technique.pomodoro),
      onFocusLogged: _state.logFocus,
    );
    _state.publishScore();
    _state.syncFromServer();
    _stopSync = _keepNotificationsInSync(_state, _timer);
  }

  @override
  void dispose() {
    _stopSync?.call();
    _timer.dispose();
    NotificationService.instance.syncSuggestions(const [], enabled: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: _state),
      ChangeNotifierProvider.value(value: _timer),
    ],
    child: const CronoEduApp(),
  );
}

/// Reprograma las notificaciones cuando cambian las sugerencias o la sesión
/// de Flowtime (solo si cambió algo relevante, no en cada segundo).
VoidCallback _keepNotificationsInSync(AppState state, StudyTimer timer) {
  final notifications = NotificationService.instance;
  String? lastSuggestions;
  void syncSuggestions() {
    final list = state.studySuggestions;
    final enabled = state.profile.notificationsEnabled;
    final sig = '$enabled|${list.map((s) => '${s.start}-${s.end}').join(',')}';
    if (sig == lastSuggestions) return;
    lastSuggestions = sig;
    notifications.syncSuggestions(list, enabled: enabled);
  }

  String? lastPresence;
  void syncPresence() {
    final checks = timer.upcomingPresenceChecks();
    final sig = checks.map((d) => d.millisecondsSinceEpoch ~/ 1000).join(',');
    if (sig == lastPresence) return;
    lastPresence = sig;
    notifications.syncPresence(checks);
  }

  state.addListener(syncSuggestions);
  timer.addListener(syncPresence);
  syncSuggestions();
  return () {
    state.removeListener(syncSuggestions);
    timer.removeListener(syncPresence);
  };
}

/// Inicio de sesión y registro (antes de tener una cuenta abierta).
class AuthApp extends StatelessWidget {
  const AuthApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CronoEdu',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const AuthScreen(),
  );
}

class CronoEduApp extends StatelessWidget {
  const CronoEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'CronoEdu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: state.profile.isRegistered ? const Shell() : const OnboardingScreen(),
    );
  }
}
