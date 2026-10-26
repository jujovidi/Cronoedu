import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/avatar.dart';

import '../services/planner.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_view.dart';
import '../widgets/crono_calendar.dart';
import '../widgets/formatters.dart';
import '../widgets/mascot.dart';
import '../widgets/suggestion_sheet.dart';
import '../widgets/task_form.dart';
import '../widgets/task_tile.dart';
import 'profile_screen.dart';
import 'shell.dart';

/// Página principal: calendario del mes (desliza para semana) con las tareas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateUtils.dateOnly(DateTime.now());
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dayTasks = state.tasksOn(_selected);
    final pending = state.pendingByDueDate;
    final t = Theme.of(context).textTheme;
    final firstName = state.profile.name.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(title: const Text('CronoEdu'), actions: const [ProfileButton()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskForm(context, date: _selected),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tarea'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          _Greeting(name: firstName, pendingCount: pending.length),
          const SizedBox(height: 12),
          CronoCalendar(
            focusedDay: _focused,
            selectedDay: _selected,
            format: _format,
            onDaySelected: (s, f) => setState(() {
              _selected = DateUtils.dateOnly(s);
              _focused = f;
            }),
            onFormatChanged: (f) => setState(() => _format = f),
            onPageChanged: (f) => _focused = f,
          ),
          if (state.nextSuggestion case final s?) ...[const SizedBox(height: 12), _ReminderCard(suggestion: s)],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(longDate(_selected), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: () => showTaskForm(context, date: _selected),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (dayTasks.isEmpty)
            const EmptyState(title: 'Sin tareas este día', message: 'Toca "Agregar" para crear una tarea pendiente.')
          else
            for (final task in dayTasks) ...[TaskTile(task), const SizedBox(height: 8)],
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.pendingCount});
  final String name;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola, $name!',
                    style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pendingCount == 0
                        ? 'No tienes tareas pendientes. ¡Disfruta!'
                        : 'Tienes $pendingCount ${pendingCount == 1 ? 'tarea pendiente' : 'tareas pendientes'}.',
                    style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .9)),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: AvatarView(context.select<AppState, AvatarLook>((s) => s.avatar), size: 84),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campanita: el próximo espacio libre para estudiar (sin materia), con
/// botón de calendario para agendarlo y "Procrastinar" para descartarlo.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.suggestion});
  final StudySuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.creative.withValues(alpha: .18),
                  child: Icon(Icons.notifications_active_rounded, color: colors.creative),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Espacio libre para estudiar', style: t.labelMedium),
                      Text(
                        slotLabel(suggestion.start, suggestion.end),
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Agendar en el horario',
                  onPressed: () => scheduleSuggestion(context, suggestion),
                  icon: const Icon(Icons.edit_calendar_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => procrastinate(context, suggestion),
                icon: const Icon(Icons.snooze_rounded, size: 18),
                label: const Text('Procrastinar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
