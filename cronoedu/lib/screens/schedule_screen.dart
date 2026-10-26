import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/schedule_block.dart';
import '../services/pdf_schedule_importer.dart';
import '../services/planner.dart';
import '../services/schedule_pdf_parser.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/block_form.dart';
import '../widgets/crono_calendar.dart';
import '../widgets/formatters.dart';
import '../widgets/mascot.dart';
import '../widgets/suggestion_sheet.dart';
import '../widgets/task_form.dart';
import '../widgets/task_tile.dart';
import '../widgets/week_timetable.dart';
import 'import_preview_screen.dart';
import 'shell.dart';

enum _View { mes, semana }

/// Página de calendario/horario: vista de mes o semana y, debajo, las
/// opciones Tarea, Ocio, Trabajo, Extracurricular y Cargar horario.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  _View _view = _View.semana;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateUtils.dateOnly(DateTime.now());
  CalendarFormat _format = CalendarFormat.month;

  DateTime get _weekStart => _selected.subtract(Duration(days: _selected.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario'), actions: const [ProfileButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          SegmentedButton<_View>(
            segments: const [
              ButtonSegment(value: _View.mes, label: Text('Mes'), icon: Icon(Icons.calendar_view_month_rounded)),
              ButtonSegment(value: _View.semana, label: Text('Semana'), icon: Icon(Icons.view_week_rounded)),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: Icon(Icons.auto_awesome_rounded, color: context.colors.success),
            title: const Text('Sugerencias de estudio autónomo', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('1 hora libre por día, en translúcido'),
            value: state.profile.showStudySuggestions,
            onChanged: state.setShowStudySuggestions,
          ),
          const SizedBox(height: 4),
          if (_view == _View.mes) ...[
            CronoCalendar(
              focusedDay: _focused,
              selectedDay: _selected,
              format: _format,
              showBlocks: true,
              onDaySelected: (s, f) => setState(() {
                _selected = DateUtils.dateOnly(s);
                _focused = f;
              }),
              onFormatChanged: (f) => setState(() => _format = f),
              onPageChanged: (f) => _focused = f,
            ),
            const SizedBox(height: 12),
            _DayAgenda(day: _selected),
          ] else ...[
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selected = _selected.subtract(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    'Semana del ${shortDate(_weekStart)}',
                    textAlign: TextAlign.center,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selected = _selected.add(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            WeekTimetable(
              weekStart: _weekStart,
              blocks: state.blocks,
              tasks: state.tasks,
              suggestions: state.profile.showStudySuggestions ? state.studySuggestions : const [],
              onSuggestionTap: (sg) => showSuggestionSheet(context, sg),
              onTaskTap: (task) => showTaskForm(context, task: task),
              onBlockTap: (b) => _showBlockDetails(context, b),
              onEmptyTap: (weekday, start) => showBlockForm(context, weekday: weekday, start: start),
            ),
            const SizedBox(height: 8),
            const _Legend(),
          ],
          const SizedBox(height: 20),
          Text('Agregar al horario', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _ActionGrid(selectedDay: _selected),
        ],
      ),
    );
  }

  void _showBlockDetails(BuildContext context, ScheduleBlock b) {
    final color = blockColor(context, b.type);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: Icon(b.type.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    b.title,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${b.type.label} · ${weekdayNames[b.weekday - 1]} ${b.start.format()} – ${b.end.format()}'),
            if (b.room.isNotEmpty) Text('Salón: ${b.room}'),
            if (b.teacher.isNotEmpty) Text('Docente: ${b.teacher}'),
            if (b.group.isNotEmpty) Text(b.group),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<AppState>().deleteBlock(b);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Eliminar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      showBlockForm(context, block: b);
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final t in BlockType.values) item(blockColor(context, t), t.label),
        item(c.success.withValues(alpha: .35), 'Sugerencia'),
        item(c.pending, 'Tarea pendiente'),
        item(c.success, 'Tarea completada'),
      ],
    );
  }
}

/// Agenda del día elegido: bloques, espacios libres y tareas que vencen.
class _DayAgenda extends StatelessWidget {
  const _DayAgenda({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final blocks = state.blocksForDate(day);
    final tasks = state.tasksOn(day);
    final suggestions = state.profile.showStudySuggestions ? state.suggestionsOn(day) : const <StudySuggestion>[];
    final t = Theme.of(context).textTheme;
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(longDate(day), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (blocks.isEmpty && tasks.isEmpty && suggestions.isEmpty)
          const EmptyState(title: 'Día libre', message: 'No hay clases ni actividades.', pose: MascotPose.descanso),
        for (final b in blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Card(
              child: ListTile(
                onTap: () => showBlockForm(context, block: b),
                leading: CircleAvatar(
                  backgroundColor: blockColor(context, b.type),
                  child: Icon(b.type.icon, color: Colors.white, size: 20),
                ),
                title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(['${b.start.format()} – ${b.end.format()}', if (b.room.isNotEmpty) b.room].join(' · ')),
              ),
            ),
          ),
        for (final sg in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: c.success.withValues(alpha: .1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: c.success.withValues(alpha: .5)),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => showSuggestionSheet(context, sg),
                leading: CircleAvatar(
                  backgroundColor: c.success.withValues(alpha: .2),
                  child: Icon(Icons.auto_awesome_rounded, color: c.success, size: 20),
                ),
                title: Text(
                  'Estudio autónomo sugerido',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.success),
                ),
                subtitle: Text('${hourMinute(sg.start)} – ${hourMinute(sg.end)} · toca para agendar'),
                trailing: IconButton(
                  tooltip: 'Agendar',
                  icon: Icon(Icons.event_available_rounded, color: c.success),
                  onPressed: () => scheduleSuggestion(context, sg),
                ),
              ),
            ),
          ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Entregas', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final task in tasks) ...[TaskTile(task), const SizedBox(height: 6)],
        ],
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.selectedDay});
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final actions = [
      (Icons.assignment_rounded, 'Tarea', c.pending, () => showTaskForm(context, date: selectedDay)),
      (BlockType.ocio.icon, 'Ocio', c.ocio, () => showBlockForm(context, type: BlockType.ocio)),
      (BlockType.trabajo.icon, 'Trabajo', c.trabajo, () => showBlockForm(context, type: BlockType.trabajo)),
      (
        BlockType.extracurricular.icon,
        'Extracurricular',
        c.extracurricular,
        () => showBlockForm(context, type: BlockType.extracurricular),
      ),
      (Icons.upload_file_rounded, 'Cargar horario', scheme.tertiary, () => _showLoadOptions(context)),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        for (final (icon, label, color, onTap) in actions)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withValues(alpha: .15),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// "Cargar horario": eliminar, editar o importar el PDF oficial.
void _showLoadOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded),
            title: const Text('Cargar horario', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Importa el reporte de horario oficial de la universidad (PDF)'),
            onTap: () {
              Navigator.pop(ctx);
              importSchedulePdf(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_rounded),
            title: const Text('Editar horario', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Crea o modifica clases, ocio, trabajo y actividades'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditScheduleScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_sweep_rounded, color: Theme.of(ctx).colorScheme.error),
            title: Text(
              'Eliminar horario',
              style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(ctx).colorScheme.error),
            ),
            subtitle: const Text('Limpia por completo las actividades del horario'),
            onTap: () async {
              Navigator.pop(ctx);
              await _confirmClear(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _confirmClear(BuildContext context) async {
  var alsoTasks = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Eliminar horario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Se borrarán todas las clases y actividades de ocio, trabajo y extracurriculares.'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: alsoTasks,
              onChanged: (v) => setState(() => alsoTasks = v ?? false),
              title: const Text('Borrar también las tareas'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ),
  );
  if (ok == true && context.mounted) {
    context.read<AppState>().clearSchedule(alsoTasks: alsoTasks);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horario eliminado')));
  }
}

/// Elige el PDF y abre la vista previa de lo reconocido.
Future<void> importSchedulePdf(BuildContext context) async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Elige tu reporte de horario (PDF)',
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (file == null || !context.mounted) return;
  try {
    final bytes = await file.readAsBytes();
    final classes = PdfScheduleImporter().importBytes(bytes);
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ImportPreviewScreen(classes: classes)));
  } on ScheduleParseException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No pude leer ese PDF. Usa el reporte de horario descargado de Academusoft.')),
    );
  }
}

/// "Editar horario": lista de bloques por día para crear, editar o borrar.
class EditScheduleScreen extends StatelessWidget {
  const EditScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Editar horario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBlockForm(context, type: BlockType.clase),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Actividad'),
      ),
      body: state.blocks.isEmpty
          ? Center(
              child: EmptyState(
                title: 'Tu horario está vacío',
                message: 'Agrega tus clases y actividades o importa el PDF oficial.',
                pose: MascotPose.escritorio,
                action: FilledButton.icon(
                  onPressed: () => importSchedulePdf(context),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Importar PDF'),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                if (state.scheduledSessions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                    child: Text(
                      'Sesiones de estudio agendadas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  for (final b in state.scheduledSessions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: blockColor(context, b.type),
                            child: Icon(b.type.icon, color: Colors.white, size: 20),
                          ),
                          title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${capitalize(shortDate(b.date!))} · ${b.start.format()} – ${b.end.format()}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => state.deleteBlock(b),
                          ),
                          onTap: () => showBlockForm(context, block: b),
                        ),
                      ),
                    ),
                ],
                for (var d = 1; d <= 7; d++)
                  if (state.blocksOn(d).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                      child: Text(
                        weekdayNames[d - 1],
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    for (final b in state.blocksOn(d))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: blockColor(context, b.type),
                              child: Icon(b.type.icon, color: Colors.white, size: 20),
                            ),
                            title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              [
                                b.type.label,
                                '${b.start.format()} – ${b.end.format()}',
                                if (b.room.isNotEmpty) b.room,
                              ].join(' · '),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => state.deleteBlock(b),
                            ),
                            onTap: () => showBlockForm(context, block: b),
                          ),
                        ),
                      ),
                  ],
              ],
            ),
    );
  }
}
