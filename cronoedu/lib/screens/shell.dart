import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/study_timer.dart';
import '../widgets/avatar_view.dart';
import '../widgets/suggestion_sheet.dart';
import 'help_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'rewards_screen.dart';
import 'schedule_screen.dart';
import 'suggestions_screen.dart';
import 'techniques_screen.dart';

class _Section {
  const _Section(this.tab, this.label, this.icon);
  final AppTab tab;
  final String label;
  final IconData icon;
}

const _sections = [
  _Section(AppTab.inicio, 'Inicio', Icons.home_rounded),
  _Section(AppTab.horario, 'Calendario', Icons.calendar_month_rounded),
  _Section(AppTab.tecnicas, 'Técnicas', Icons.timer_rounded),
  _Section(AppTab.sugerencias, 'Sugerencias', Icons.lightbulb_rounded),
  _Section(AppTab.recompensas, 'Recompensas', Icons.emoji_events_rounded),
];

/// Contenedor principal. Abajo hay un botón que despliega los apartados.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  bool _menuOpen = false;
  StreamSubscription<NotificationTap>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = NotificationService.instance;
    _taps = notifications.taps.listen(_onNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      notifications.requestPermission();
      if (!state.profile.tutorialSeen) {
        state.markTutorialSeen();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen()));
      }
      final launch = notifications.launchTap;
      if (launch != null) {
        notifications.launchTap = null;
        _onNotificationTap(launch);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) return;
    // Descartes hechos desde la notificación y fin de fases en segundo plano.
    context.read<AppState>().refreshDismissed();
    final timer = context.read<StudyTimer>();
    if (timer.isRunning) timer.tick();
  }

  void _onNotificationTap(NotificationTap tap) {
    if (!mounted) return;
    final payload = tap.payload ?? '';
    if (payload == 'presencia') {
      context.read<StudyTimer>().confirmPresence();
      _go(AppTab.tecnicas);
      return;
    }
    if (!payload.startsWith('sugerencia:')) return;
    final state = context.read<AppState>();
    final s = state.suggestionByKey(payload.substring('sugerencia:'.length));
    if (s == null) return;
    switch (tap.action) {
      case NotificationActions.agendar:
        scheduleSuggestion(context, s);
        _go(AppTab.horario);
      case NotificationActions.procrastinar:
        procrastinate(context, s);
      default:
        _go(AppTab.horario);
        showSuggestionSheet(context, s);
    }
  }

  void _go(AppTab tab) {
    context.read<AppState>().selectTab(tab);
    setState(() => _menuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final tab = context.select<AppState, AppTab>((s) => s.tab);
    final scheme = Theme.of(context).colorScheme;
    final current = _sections.firstWhere((s) => s.tab == tab);

    return PopScope(
      canPop: tab == AppTab.inicio && !_menuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_menuOpen) {
          setState(() => _menuOpen = false);
        } else {
          _go(AppTab.inicio);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: tab.index,
              children: const [
                HomeScreen(),
                ScheduleScreen(),
                TechniquesScreen(),
                SuggestionsScreen(),
                RewardsScreen(),
              ],
            ),
            // Fondo que cierra el menú al tocar fuera.
            if (_menuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _menuOpen = false),
                  child: Container(color: Colors.black.withValues(alpha: .25)),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: Material(
                color: scheme.surface,
                elevation: 6,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_menuOpen) ...[
                        for (final s in _sections)
                          ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            selected: s.tab == tab,
                            selectedTileColor: scheme.primary.withValues(alpha: .1),
                            leading: Icon(s.icon),
                            title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () => _go(s.tab),
                          ),
                        const Divider(height: 8),
                      ],
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(current.icon, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              current.label,
                              style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => setState(() => _menuOpen = !_menuOpen),
                            icon: AnimatedRotation(
                              turns: _menuOpen ? .5 : 0,
                              duration: const Duration(milliseconds: 250),
                              child: const Icon(Icons.keyboard_arrow_up_rounded),
                            ),
                            label: Text(_menuOpen ? 'Cerrar' : 'Apartados'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícono de usuario en la esquina que lleva al perfil.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final avatar = context.select<AppState, AvatarLook>((s) => s.avatar);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: Tooltip(message: 'Perfil', child: AvatarView(avatar, size: 40)),
      ),
    );
  }
}
