import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'planner.dart';
import 'storage_service.dart';

/// Acciones de los botones de las notificaciones.
class NotificationActions {
  static const verEspacio = 'ver';
  static const agendar = 'agendar';
  static const procrastinar = 'procrastinar';
  static const sigoAqui = 'sigo';
}

/// Lo que el usuario tocó en una notificación.
class NotificationTap {
  NotificationTap(this.action, this.payload);

  /// null = tocó la notificación (no un botón).
  final String? action;
  final String? payload;
}

/// "Procrastinar" con la app cerrada: se guarda el descarte sin abrirla.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  if (response.actionId != NotificationActions.procrastinar) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(StorageService.kDismissed) ?? [];
  final key = response.payload?.replaceFirst('sugerencia:', '');
  if (key != null && !list.contains(key)) {
    await prefs.setStringList(StorageService.kDismissed, [...list, key]);
  }
}

/// Notificaciones locales del sistema:
/// - 30 minutos antes de cada hora sugerida de estudio, con los botones
///   "Ver espacio", "Agendar" y "Procrastinar".
/// - "¿Sigues ahí?" en Flowtime después de 2 horas de enfoque.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<NotificationTap>.broadcast();
  bool _ready = false;

  /// Toques en notificaciones mientras la app está abierta.
  Stream<NotificationTap> get taps => _taps.stream;

  /// Toque que abrió la app (si la abrió una notificación).
  NotificationTap? launchTap;

  static const _suggestionBase = 1000;
  static const _presenceBase = 2000;
  static const _maxSuggestions = 14;
  static const _maxPresence = 6;

  static const _suggestionChannel = AndroidNotificationDetails(
    'sugerencias_estudio',
    'Sugerencias de estudio',
    channelDescription: 'Avisos de espacios libres para estudiar',
    importance: Importance.high,
    priority: Priority.high,
    actions: [
      AndroidNotificationAction(NotificationActions.verEspacio, 'Ver espacio', showsUserInterface: true),
      AndroidNotificationAction(NotificationActions.agendar, 'Agendar', showsUserInterface: true),
      AndroidNotificationAction(NotificationActions.procrastinar, 'Procrastinar'),
    ],
  );

  static const _presenceChannel = AndroidNotificationDetails(
    'sigues_ahi',
    'Sesión de estudio',
    channelDescription: 'Pregunta "¿Sigues ahí?" en sesiones largas de Flowtime',
    importance: Importance.max,
    priority: Priority.max,
    actions: [AndroidNotificationAction(NotificationActions.sigoAqui, '¡Sí, sigo aquí!', showsUserInterface: true)],
  );

  Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) => _taps.add(NotificationTap(r.actionId, r.payload)),
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final r = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && r != null) {
      launchTap = NotificationTap(r.actionId, r.payload);
    }
    _ready = true;
  }

  /// Pide permiso de notificaciones (Android 13+).
  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Reprograma los avisos de las horas sugeridas.
  Future<void> syncSuggestions(List<StudySuggestion> suggestions, {required bool enabled}) async {
    if (!_ready) return;
    for (var i = 0; i < _maxSuggestions; i++) {
      await _plugin.cancel(id: _suggestionBase + i);
    }
    if (!enabled) return;
    final now = DateTime.now();
    var i = 0;
    for (final s in suggestions) {
      if (i >= _maxSuggestions) break;
      final at = s.start.subtract(const Duration(minutes: 30));
      if (!at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: _suggestionBase + i++,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: const NotificationDetails(android: _suggestionChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Tienes un espacio libre para estudiar',
        body: 'De ${_hm(s.start)} a ${_hm(s.end)}. ¿Lo agendamos?',
        payload: 'sugerencia:${s.key}',
      );
    }
  }

  /// Programa las preguntas "¿Sigues ahí?" de la sesión de Flowtime en curso.
  Future<void> syncPresence(List<DateTime> checks) async {
    if (!_ready) return;
    for (var i = 0; i < _maxPresence; i++) {
      await _plugin.cancel(id: _presenceBase + i);
    }
    var i = 0;
    for (final at in checks.take(_maxPresence)) {
      await _plugin.zonedSchedule(
        id: _presenceBase + i++,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: const NotificationDetails(android: _presenceChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '¿Sigues ahí?',
        body: 'Llevas un buen rato estudiando. Si no respondes en 1 minuto, cerramos la sesión y empieza tu descanso.',
        payload: 'presencia',
      );
    }
  }

  static String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
