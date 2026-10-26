import 'package:flutter/material.dart';

import '../models/schedule_block.dart';
import '../models/task.dart';
import '../services/planner.dart';
import '../theme/app_theme.dart';
import 'crono_calendar.dart' show blockColor;

/// Cuadrícula semanal (lunes a domingo) con los bloques del horario. Encima,
/// en translúcido:
/// - las tareas en su fecha y hora de entrega (o sobre la clase de la
///   materia si se entregan en físico),
/// - las horas sugeridas de estudio autónomo.
class WeekTimetable extends StatelessWidget {
  const WeekTimetable({
    super.key,
    required this.weekStart,
    required this.blocks,
    required this.tasks,
    required this.onBlockTap,
    this.suggestions = const [],
    this.onSuggestionTap,
    this.onTaskTap,
    this.onEmptyTap,
  });

  /// Lunes de la semana mostrada.
  final DateTime weekStart;
  final List<ScheduleBlock> blocks;
  final List<Task> tasks;
  final List<StudySuggestion> suggestions;
  final ValueChanged<ScheduleBlock> onBlockTap;
  final ValueChanged<StudySuggestion>? onSuggestionTap;
  final ValueChanged<Task>? onTaskTap;
  final void Function(int weekday, DayTime start)? onEmptyTap;

  static const _hourHeight = 44.0;
  static const _timeColWidth = 38.0;

  DateTime _dayOf(int weekday) => weekStart.add(Duration(days: weekday - 1));

  /// Bloques que se ven esta semana (semanales + sesiones de un día de esta semana).
  List<ScheduleBlock> get _weekBlocks => blocks.where((b) => b.appliesTo(_dayOf(b.weekday))).toList();

  static String _norm(String s) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    var r = s.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  /// Clase de la materia de la tarea ese día (para entregas en físico).
  ScheduleBlock? _classFor(Task t, List<ScheduleBlock> week) {
    final subject = _norm(t.subject);
    if (subject.isEmpty) return null;
    final candidates = week.where((b) {
      if (b.type != BlockType.clase || !b.appliesTo(t.dueDate)) return false;
      final title = _norm(b.title);
      return title.contains(subject) || subject.contains(title);
    }).toList();
    if (candidates.isEmpty) return null;
    // Si tiene hora, la clase más cercana a esa hora.
    final time = t.dueTime;
    if (time != null) {
      candidates.sort(
        (a, b) => (a.start.inMinutes - time.inMinutes).abs().compareTo((b.start.inMinutes - time.inMinutes).abs()),
      );
    }
    return candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.colors;
    final week = _weekBlocks;
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weekTasks = tasks.where((t) => !t.dueDate.isBefore(weekStart) && t.dueDate.isBefore(weekEnd)).toList();
    final weekSuggestions = suggestions
        .where((s) => !s.start.isBefore(weekStart) && s.start.isBefore(weekEnd))
        .toList();

    var startHour = 7;
    var endHour = 21;
    void widen(int startMin, int endMin) {
      if (startMin ~/ 60 < startHour) startHour = startMin ~/ 60;
      final e = (endMin / 60).ceil();
      if (e > endHour) endHour = e.clamp(0, 24);
    }

    for (final b in week) {
      widen(b.start.inMinutes, b.end.inMinutes);
    }
    for (final t in weekTasks) {
      if (t.dueTime != null) widen(t.dueTime!.inMinutes, t.dueTime!.inMinutes + 30);
    }
    final hours = endHour - startHour;
    final today = DateUtils.dateOnly(DateTime.now());

    // Ubicación de cada tarea: sobre su clase, en su hora, o solo en el encabezado.
    final placedTasks = <(Task, int weekday, int startMin, int endMin)>[];
    final headerTasks = <Task>[];
    for (final t in weekTasks) {
      final cls = t.delivery == DeliveryMode.fisico ? _classFor(t, week) : null;
      if (cls != null) {
        placedTasks.add((t, t.dueDate.weekday, cls.start.inMinutes, cls.end.inMinutes));
      } else if (t.dueTime != null) {
        final s = t.dueTime!.inMinutes.clamp(startHour * 60, endHour * 60 - 30);
        placedTasks.add((t, t.dueDate.weekday, s, s + 30));
      } else {
        headerTasks.add(t);
      }
    }

    double top(int minutes) => (minutes - startHour * 60) / 60 * _hourHeight;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, c) {
            final dayWidth = (c.maxWidth - _timeColWidth) / 7;
            double left(int weekday) => _timeColWidth + (weekday - 1) * dayWidth;
            return Column(
              children: [
                // Encabezado de días
                Row(
                  children: [
                    const SizedBox(width: _timeColWidth),
                    for (var d = 0; d < 7; d++)
                      SizedBox(
                        width: dayWidth,
                        child: Builder(
                          builder: (context) {
                            final date = weekStart.add(Duration(days: d));
                            final isToday = DateUtils.isSameDay(date, today);
                            final dayTasks = headerTasks.where((t) => DateUtils.isSameDay(t.dueDate, date)).toList();
                            return Column(
                              children: [
                                Text(
                                  weekdayShort[d],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isToday ? scheme.primary : null,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isToday ? Colors.white : scheme.onSurface,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 10,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (final t in dayTasks.take(3))
                                        GestureDetector(
                                          onTap: onTaskTap == null ? null : () => onTaskTap!(t),
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.all(1),
                                            decoration: BoxDecoration(
                                              color: t.isPending ? colors.pending : colors.success,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const Divider(height: 4),
                SizedBox(
                  height: hours * _hourHeight,
                  child: Stack(
                    children: [
                      // Líneas de hora
                      for (var h = 0; h < hours; h++)
                        Positioned(
                          top: h * _hourHeight,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              SizedBox(
                                width: _timeColWidth,
                                child: Text(
                                  '${startHour + h}:00',
                                  style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                                ),
                              ),
                              Expanded(child: Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .5))),
                            ],
                          ),
                        ),
                      // Toques en espacios vacíos
                      if (onEmptyTap != null)
                        Positioned(
                          left: _timeColWidth,
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (d) {
                              final weekday = (d.localPosition.dx ~/ dayWidth).clamp(0, 6) + 1;
                              final hour = startHour + (d.localPosition.dy ~/ _hourHeight);
                              onEmptyTap!(weekday, DayTime(hour, 0));
                            },
                          ),
                        ),
                      // Bloques
                      for (final b in week)
                        Positioned(
                          left: left(b.weekday) + 1,
                          width: dayWidth - 2,
                          top: top(b.start.inMinutes) + 1,
                          height: (b.durationMinutes / 60 * _hourHeight - 2).clamp(14, double.infinity),
                          child: _BlockChip(block: b, onTap: () => onBlockTap(b)),
                        ),
                      // Sugerencias de estudio (translúcidas)
                      for (final s in weekSuggestions)
                        Positioned(
                          left: left(s.start.weekday) + 1,
                          width: dayWidth - 2,
                          top: top(s.start.hour * 60 + s.start.minute) + 1,
                          height: (s.end.difference(s.start).inMinutes / 60 * _hourHeight - 2).clamp(
                            14,
                            double.infinity,
                          ),
                          child: _GhostChip(
                            color: colors.success,
                            icon: Icons.auto_awesome_rounded,
                            label: 'Estudiar',
                            onTap: onSuggestionTap == null ? null : () => onSuggestionTap!(s),
                          ),
                        ),
                      // Tareas (translúcidas) sobre su hora o su clase
                      for (final (t, weekday, s, e) in placedTasks)
                        Positioned(
                          left: left(weekday) + 2,
                          width: dayWidth - 4,
                          top: top(e) - 24 > top(s) ? top(e) - 24 : top(s) + 1,
                          height: 22,
                          child: _GhostChip(
                            color: t.isPending ? colors.pending : colors.success,
                            icon: t.delivery == DeliveryMode.fisico ? Icons.description_rounded : Icons.flag_rounded,
                            label: t.topic.isEmpty ? t.subject : t.topic,
                            strong: true,
                            onTap: onTaskTap == null ? null : () => onTaskTap!(t),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.block, required this.onTap});
  final ScheduleBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = blockColor(context, block.type);
    return Material(
      color: color.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Text(
            block.room.isEmpty ? block.title : '${block.title}\n${block.room}',
            overflow: TextOverflow.fade,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, height: 1.15),
          ),
        ),
      ),
    );
  }
}

/// Elemento translúcido (tarea o sugerencia) sobre la cuadrícula.
class _GhostChip extends StatelessWidget {
  const _GhostChip({required this.color, required this.icon, required this.label, this.onTap, this.strong = false});

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: strong ? .55 : .2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: .8), width: 1),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final text = Text(
              label,
              maxLines: c.maxHeight >= 26 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: c.maxHeight >= 26 ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: 8.5,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: strong ? Colors.white : color,
              ),
            );
            final iconW = Icon(icon, size: 11, color: strong ? Colors.white : color);
            // En bloques altos: ícono arriba y texto debajo; en bajos, en fila.
            if (c.maxHeight >= 26) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconW,
                    Flexible(child: text),
                  ],
                ),
              );
            }
            return Row(
              children: [
                iconW,
                const SizedBox(width: 2),
                Expanded(child: text),
              ],
            );
          },
        ),
      ),
    );
  }
}
