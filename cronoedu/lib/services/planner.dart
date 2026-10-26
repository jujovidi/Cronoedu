import '../models/schedule_block.dart';
import '../models/task.dart';

/// Un espacio libre concreto en el calendario.
class FreeSlot {
  FreeSlot(this.start, this.end);
  final DateTime start;
  final DateTime end;
  Duration get duration => end.difference(start);
}

/// Hora sugerida de estudio autónomo (siempre de máximo 1 hora).
class StudySuggestion {
  StudySuggestion(this.start, this.end, this.task);
  final DateTime start;
  final DateTime end;

  /// Tarea más urgente para aprovechar ese espacio (uso interno).
  final Task? task;

  /// Identificador del día ("aaaa-mm-dd"): hay como mucho una sugerencia por
  /// día, así que descartarla ("Procrastinar") descarta la de ese día.
  String get key => keyFor(start);

  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Detecta espacios vacíos en el horario (respetando clases, ocio, trabajo,
/// extracurriculares y sesiones agendadas) para recomendar cuándo estudiar.
class Planner {
  const Planner({this.dayStart = const DayTime(7, 0), this.dayEnd = const DayTime(22, 0), this.minSlotMinutes = 30});

  final DayTime dayStart;
  final DayTime dayEnd;
  final int minSlotMinutes;

  /// Espacios libres de un día concreto. Si [after] cae dentro del día, solo
  /// devuelve lo que queda desde ese momento.
  List<FreeSlot> freeSlotsOn(DateTime day, List<ScheduleBlock> blocks, {DateTime? after}) {
    final date = DateTime(day.year, day.month, day.day);
    final busy = blocks.where((b) => b.appliesTo(date)).toList()..sort((a, b) => a.start.compareTo(b.start));

    var cursor = dayStart.inMinutes;
    if (after != null) {
      final afterDay = DateTime(after.year, after.month, after.day);
      if (afterDay.isAfter(date)) return [];
      if (afterDay == date) {
        final nowMin = after.hour * 60 + after.minute;
        if (nowMin > cursor) cursor = nowMin;
      }
    }
    final result = <FreeSlot>[];
    void addGap(int from, int to) {
      if (to - from >= minSlotMinutes) {
        result.add(FreeSlot(date.add(Duration(minutes: from)), date.add(Duration(minutes: to))));
      }
    }

    for (final b in busy) {
      if (b.end.inMinutes <= cursor) continue;
      if (b.start.inMinutes > cursor) {
        addGap(cursor, b.start.inMinutes.clamp(cursor, dayEnd.inMinutes));
      }
      if (b.end.inMinutes > cursor) cursor = b.end.inMinutes;
      if (cursor >= dayEnd.inMinutes) break;
    }
    if (cursor < dayEnd.inMinutes) addGap(cursor, dayEnd.inMinutes);
    return result;
  }

  /// Primer espacio libre desde [now] y antes de la entrega de [task].
  FreeSlot? nextSlotFor(Task task, List<ScheduleBlock> blocks, {DateTime? now}) {
    final from = now ?? DateTime.now();
    final lastDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    var day = DateTime(from.year, from.month, from.day);
    for (var i = 0; i < 14 && !day.isAfter(lastDay); i++) {
      final slots = freeSlotsOn(day, blocks, after: from);
      if (slots.isNotEmpty) return slots.first;
      day = day.add(const Duration(days: 1));
    }
    return null;
  }

  /// Una hora sugerida de estudio autónomo por día, durante [days] días,
  /// mientras haya tareas pendientes que entregar ese día o después. Empieza
  /// en el primer espacio libre (redondeado a la media hora siguiente). Los
  /// días descartados o con una sesión ya agendada se saltan.
  List<StudySuggestion> studySuggestions(
    List<Task> tasks,
    List<ScheduleBlock> blocks, {
    Set<String> dismissed = const {},
    DateTime? now,
    int days = 7,
  }) {
    final from = _roundUpHalfHour(now ?? DateTime.now());
    final pending = tasks.where((t) => t.isPending).toList();
    if (pending.isEmpty) return [];
    final result = <StudySuggestion>[];
    var day = DateTime(from.year, from.month, from.day);
    for (var i = 0; i < days; i++, day = day.add(const Duration(days: 1))) {
      final candidates = pending.where((t) => !t.dueDateTime.isBefore(day)).toList()
        ..sort((a, b) => b.priority(day).compareTo(a.priority(day)));
      if (candidates.isEmpty) continue;
      if (dismissed.contains(StudySuggestion.keyFor(day))) continue;
      // Si ya agendó una sesión de estudio ese día, no se sugiere otra.
      if (blocks.any((b) => b.isOneOff && b.type == BlockType.estudio && b.appliesTo(day))) continue;
      for (final slot in freeSlotsOn(day, blocks, after: from)) {
        final start = _roundUpHalfHour(slot.start);
        var end = start.add(const Duration(hours: 1));
        if (end.isAfter(slot.end)) end = slot.end;
        if (end.difference(start).inMinutes < minSlotMinutes) continue;
        result.add(StudySuggestion(start, end, candidates.first));
        break;
      }
    }
    return result;
  }

  /// Horas libres totales entre hoy y la entrega.
  double freeHoursUntil(Task task, List<ScheduleBlock> blocks, {DateTime? now}) {
    final from = now ?? DateTime.now();
    var day = DateTime(from.year, from.month, from.day);
    final lastDay = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    var minutes = 0;
    while (!day.isAfter(lastDay)) {
      for (final s in freeSlotsOn(day, blocks, after: from)) {
        minutes += s.duration.inMinutes;
      }
      day = day.add(const Duration(days: 1));
    }
    return minutes / 60;
  }

  /// Minutos sugeridos por sesión de estudio según la complejidad.
  int suggestedSessionMinutes(Task task) => switch (task.complexity) {
    TaskComplexity.tareita => 50,
    TaskComplexity.proyecto => 90,
    TaskComplexity.proyectoFinal => 120,
  };

  /// Mensaje corto para explicarle al usuario qué tan apretado está.
  String workloadHint(Task task, List<ScheduleBlock> blocks, {DateTime? now}) {
    final days = task.daysLeft(now);
    if (days < 0) return 'Esta tarea ya venció.';
    final needed = task.complexity.estimatedHours;
    final free = freeHoursUntil(task, blocks, now: now);
    if (free < needed) {
      return 'Necesitas ~${_fmtHours(needed)} y solo tienes '
          '${_fmtHours(free)} libres antes de la entrega. ¡Empieza ya!';
    }
    if (days <= task.complexity.daysAhead) {
      return 'Te tomará ~${_fmtHours(needed)}. Buen momento para empezar.';
    }
    return 'Te tomará ~${_fmtHours(needed)}. Tienes ${_fmtHours(free)} libres.';
  }

  static DateTime _roundUpHalfHour(DateTime d) {
    final base = DateTime(d.year, d.month, d.day, d.hour);
    final m = d.minute + (d.second > 0 || d.millisecond > 0 ? 1 : 0);
    if (m == 0) return base;
    if (m <= 30) return base.add(const Duration(minutes: 30));
    return base.add(const Duration(hours: 1));
  }

  static String _fmtHours(double h) {
    if (h < 1) return '${(h * 60).round()} min';
    final r = (h * 10).round() / 10;
    return r == r.roundToDouble() ? '${r.round()} h' : '$r h';
  }
}
