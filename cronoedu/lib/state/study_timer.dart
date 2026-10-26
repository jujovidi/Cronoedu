import 'dart:async';

import 'package:flutter/foundation.dart';

enum Technique { pomodoro, flowtime }

/// Los 4 estados del temporizador de la propuesta de diseño (más "listo").
enum TimerPhase {
  listo, // aún no empieza
  enfoque, // 1. sesión activa
  pausa, // 2. en pausa
  descanso, // 3. descanso
  logro, // 4. finalizado / logro
}

/// Temporizador de estudio para Pomodoro y Flowtime. Se calcula con la hora
/// real (no contando ticks), así que sigue siendo exacto si la app se va a
/// segundo plano un momento.
///
/// Un ciclo se cierra al terminar (u omitir) el descanso que sigue a un
/// enfoque válido.
class StudyTimer extends ChangeNotifier {
  StudyTimer({this.onCycleCompleted, this.onFocusLogged, DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// Se llama cada vez que se cierra un ciclo (fin del descanso).
  void Function(Technique technique)? onCycleCompleted;

  /// Se llama con la duración de cada enfoque válido.
  void Function(Duration focus)? onFocusLogged;

  static const pomodoroFocus = Duration(minutes: 25);
  static const pomodoroShortBreak = Duration(minutes: 5);
  static const pomodoroLongBreak = Duration(minutes: 15);
  static const cyclesBeforeLongBreak = 4;

  /// Flowtime: mínimo de enfoque para que cuente como sesión válida.
  static const flowtimeMinFocus = Duration(minutes: 10);

  /// Flowtime: a partir de 2 h de enfoque se pregunta "¿Sigues ahí?" cada hora.
  static const presenceFirstCheck = Duration(hours: 2);
  static const presenceEvery = Duration(hours: 1);

  /// Tiempo para responder antes de dar el enfoque por terminado.
  static const presenceTimeout = Duration(minutes: 1);

  Technique _technique = Technique.pomodoro;
  TimerPhase _phase = TimerPhase.listo;
  TimerPhase _phaseBeforePause = TimerPhase.enfoque;

  /// Duración total de la fase actual (null en Flowtime-enfoque: es abierto).
  Duration? _phaseTotal;
  DateTime? _phaseStartedAt;
  Duration _elapsedBeforePause = Duration.zero;
  Duration _lastFocus = Duration.zero;
  int _sessionCycles = 0;
  bool _cyclePending = false;
  bool _endedByAbsence = false;
  Duration _nextPresenceCheck = presenceFirstCheck;
  Timer? _ticker;

  Technique get technique => _technique;
  TimerPhase get phase => _phase;
  bool get isRunning => _phase == TimerPhase.enfoque || _phase == TimerPhase.descanso;
  bool get isPaused => _phase == TimerPhase.pausa;
  bool get isIdle => _phase == TimerPhase.listo;
  bool get pausedFromFocus => _phaseBeforePause == TimerPhase.enfoque;
  bool get inFocus => _phase == TimerPhase.enfoque || (isPaused && pausedFromFocus);

  /// Ciclos cerrados en esta sesión (desde que se abrió la técnica).
  int get sessionCycles => _sessionCycles;

  /// Duración del último bloque de enfoque (para la tarjeta de logro).
  Duration get lastFocus => _lastFocus;

  /// El último enfoque terminó porque no respondió "¿Sigues ahí?".
  bool get endedByAbsence => _endedByAbsence;

  /// Tiempo transcurrido en la fase actual.
  Duration get elapsed {
    if (_phaseStartedAt == null) return _elapsedBeforePause;
    return _elapsedBeforePause + _now().difference(_phaseStartedAt!);
  }

  /// En Flowtime: ¿el enfoque actual ya alcanza el mínimo para contar?
  bool get focusIsValid => _technique == Technique.pomodoro || elapsed >= flowtimeMinFocus;

  /// Tiempo restante (o transcurrido si es Flowtime en enfoque).
  Duration get display {
    final total = _phaseTotal;
    if (_phase == TimerPhase.listo) {
      return _technique == Technique.pomodoro ? pomodoroFocus : Duration.zero;
    }
    if (total == null) return elapsed;
    final left = total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Progreso del anillo (0..1). En Flowtime-enfoque da una vuelta por hora.
  double get progress {
    final total = _phaseTotal;
    if (_phase == TimerPhase.listo) return 0;
    if (_phase == TimerPhase.logro) return 1;
    if (total == null) return (elapsed.inSeconds % 3600) / 3600;
    if (total.inSeconds == 0) return 1;
    return (elapsed.inMilliseconds / total.inMilliseconds).clamp(0, 1);
  }

  // ---------- "¿Sigues ahí?" (Flowtime) ----------

  bool get _checksPresence => _technique == Technique.flowtime && _phase == TimerPhase.enfoque;

  /// Momento (hora real) en que se hizo la pregunta pendiente, si la hay.
  DateTime? get presenceAskedAt {
    if (!_checksPresence || elapsed < _nextPresenceCheck) return null;
    return _phaseStartedAt!.add(_nextPresenceCheck - _elapsedBeforePause);
  }

  bool get awaitingPresence => presenceAskedAt != null;

  /// Segundos que quedan para responder.
  Duration get presenceTimeLeft {
    final asked = presenceAskedAt;
    if (asked == null) return Duration.zero;
    final left = presenceTimeout - _now().difference(asked);
    return left.isNegative ? Duration.zero : left;
  }

  /// Próximas preguntas programadas (hora real), para avisar con notificación.
  List<DateTime> upcomingPresenceChecks({int count = 4}) {
    if (!_checksPresence) return const [];
    final start = _phaseStartedAt!.subtract(_elapsedBeforePause);
    return [
      for (var i = 0; i < count; i++) start.add(_nextPresenceCheck + presenceEvery * i),
    ].where((d) => d.isAfter(_now())).toList();
  }

  /// Respuesta "¡Sí, sigo aquí!".
  void confirmPresence() {
    if (!awaitingPresence) return;
    _nextPresenceCheck += presenceEvery;
    notifyListeners();
  }

  // ---------- Controles ----------

  void selectTechnique(Technique t) {
    if (t == _technique) return;
    _technique = t;
    reset();
  }

  void start() {
    _endedByAbsence = false;
    _nextPresenceCheck = presenceFirstCheck;
    _beginPhase(TimerPhase.enfoque, _technique == Technique.pomodoro ? pomodoroFocus : null);
  }

  void pause() {
    if (!isRunning) return;
    if (awaitingPresence) confirmPresence(); // pausar es señal de que está ahí
    _elapsedBeforePause = elapsed;
    _phaseStartedAt = null;
    _phaseBeforePause = _phase;
    _phase = TimerPhase.pausa;
    _ticker?.cancel();
    notifyListeners();
  }

  void resume() {
    if (!isPaused) return;
    _phase = _phaseBeforePause;
    _phaseStartedAt = _now();
    _startTicker();
    notifyListeners();
  }

  /// Termina el enfoque y empieza el descanso. Devuelve false (sin hacer
  /// nada) si en Flowtime aún no se cumplen los 10 minutos mínimos.
  bool finishFocus({Duration? focusOverride}) {
    if (!inFocus) return false;
    final focus = focusOverride ?? elapsed;
    if (_technique == Technique.flowtime && focus < flowtimeMinFocus) return false;
    _lastFocus = focus;
    _cyclePending = true;
    onFocusLogged?.call(focus);
    _beginPhase(TimerPhase.descanso, breakFor(focus));
    return true;
  }

  /// Fin del descanso (o "Omitir descanso"): se cierra el ciclo.
  void skipBreak() {
    _ticker?.cancel();
    if (_cyclePending) {
      _cyclePending = false;
      _sessionCycles++;
      onCycleCompleted?.call(_technique);
    }
    _phase = TimerPhase.logro;
    _phaseStartedAt = null;
    _elapsedBeforePause = Duration.zero;
    notifyListeners();
  }

  /// "Abandonar": descarta el bloque actual sin contar el ciclo.
  void reset() {
    _ticker?.cancel();
    _phase = TimerPhase.listo;
    _phaseTotal = null;
    _phaseStartedAt = null;
    _elapsedBeforePause = Duration.zero;
    _cyclePending = false;
    notifyListeners();
  }

  /// Descanso recomendado.
  Duration breakFor(Duration focus) {
    if (_technique == Technique.pomodoro) {
      return (_sessionCycles + 1) % cyclesBeforeLongBreak == 0 ? pomodoroLongBreak : pomodoroShortBreak;
    }
    // Flowtime: descanso proporcional al tiempo de enfoque.
    final m = focus.inMinutes;
    if (m < 25) return const Duration(minutes: 5);
    if (m < 50) return const Duration(minutes: 8);
    if (m <= 90) return const Duration(minutes: 10);
    return Duration(seconds: focus.inSeconds ~/ 4); // más de 90 min: 1/4
  }

  void _beginPhase(TimerPhase phase, Duration? total) {
    _phase = phase;
    _phaseTotal = total;
    _phaseStartedAt = _now();
    _elapsedBeforePause = Duration.zero;
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => tick());
  }

  /// Revisa si la fase terminó. Público para poder forzarlo al volver a la app.
  void tick() {
    final asked = presenceAskedAt;
    if (asked != null && _now().difference(asked) >= presenceTimeout) {
      // No respondió: el enfoque cuenta hasta el momento de la pregunta.
      final focus = _nextPresenceCheck;
      _endedByAbsence = true;
      finishFocus(focusOverride: focus);
      return;
    }
    final total = _phaseTotal;
    if (total != null && elapsed >= total) {
      if (_phase == TimerPhase.enfoque) {
        finishFocus();
        return;
      }
      if (_phase == TimerPhase.descanso) {
        skipBreak();
        return;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
