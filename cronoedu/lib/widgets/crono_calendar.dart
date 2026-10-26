import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/schedule_block.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

Color blockColor(BuildContext context, BlockType type) {
  final c = context.colors;
  return switch (type) {
    BlockType.clase => c.clase,
    BlockType.ocio => c.ocio,
    BlockType.trabajo => c.trabajo,
    BlockType.extracurricular => c.extracurricular,
    BlockType.estudio => c.focus,
  };
}

/// Calendario mensual que al deslizar hacia arriba pasa a vista semanal (y
/// hacia abajo vuelve a mes). Marca las tareas: rojo pendiente, verde hecha.
class CronoCalendar extends StatelessWidget {
  const CronoCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.format,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
    this.showBlocks = false,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat format;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;

  /// Además de tareas, muestra una barrita por los bloques del día de semana.
  final bool showBlocks;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final colors = context.colors;
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            TableCalendar<Task>(
              locale: 'es',
              firstDay: DateTime(now.year - 2),
              lastDay: DateTime(now.year + 3, 12, 31),
              focusedDay: focusedDay,
              selectedDayPredicate: (d) => isSameDay(d, selectedDay),
              calendarFormat: format,
              availableCalendarFormats: const {CalendarFormat.month: 'Mes', CalendarFormat.week: 'Semana'},
              availableGestures: AvailableGestures.all,
              startingDayOfWeek: StartingDayOfWeek.monday,
              eventLoader: state.tasksOn,
              onDaySelected: onDaySelected,
              onFormatChanged: onFormatChanged,
              onPageChanged: onPageChanged,
              rowHeight: 46,
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: true,
                formatButtonShowsNext: false,
                titleTextFormatter: (d, l) {
                  final s = DateFormatCache.monthYear(d);
                  return s[0].toUpperCase() + s.substring(1);
                },
                titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                formatButtonDecoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                formatButtonTextStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                weekendStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: TextStyle(color: scheme.onSurface),
                weekendTextStyle: TextStyle(color: scheme.onSurface),
                todayDecoration: BoxDecoration(color: scheme.secondary.withValues(alpha: .25), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800),
                selectedDecoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              calendarBuilders: CalendarBuilders<Task>(
                markerBuilder: (context, day, tasks) {
                  final blocks = showBlocks ? state.blocksForDate(day) : const <ScheduleBlock>[];
                  if (tasks.isEmpty && blocks.isEmpty) return null;
                  final pending = tasks.where((t) => t.isPending).length;
                  final done = tasks.length - pending;
                  return Positioned(
                    bottom: 3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (blocks.isNotEmpty)
                          Container(
                            width: 10,
                            height: 3,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              color: blockColor(context, blocks.first.type),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        for (var i = 0; i < pending.clamp(0, 3); i++) _dot(colors.pending),
                        for (var i = 0; i < done.clamp(0, 3); i++) _dot(colors.success),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  format == CalendarFormat.month ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                Text(
                  format == CalendarFormat.month
                      ? 'Desliza hacia arriba para ver la semana'
                      : 'Desliza hacia abajo para ver el mes',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 6,
    height: 6,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

/// Formato "octubre 2026" en español.
class DateFormatCache {
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  static String monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';
}
