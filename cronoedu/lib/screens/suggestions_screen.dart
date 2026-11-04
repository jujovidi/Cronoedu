import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_block.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/block_form.dart';
import '../widgets/formatters.dart';
import '../widgets/reward_feedback.dart';
import '../widgets/study_materials.dart';
import '../widgets/task_form.dart';
import 'shell.dart';

/// Una ficha del carrusel: tarea pendiente, sesión de estudio agendada o la
/// ficha para explorar una materia (siempre la última).
class _Ficha {
  _Ficha.task(Task this.task) : session = null, key = 'tarea:${task.id}', when = task.dueDateTime;
  _Ficha.session(StudySession this.session) : task = null, key = 'sesion:${session.block.id}', when = session.start;
  _Ficha.explore() : task = null, session = null, key = 'explorar', when = null;

  final Task? task;
  final StudySession? session;
  final String key;
  final DateTime? when;
}

/// Sugerencias de estudio: carrusel con las tareas pendientes y las sesiones
/// de estudio agendadas, por fecha. La actual se ve grande; al deslizar se
/// encoge y aparece la siguiente. Al final está "Explorar una materia".
class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  final _controller = PageController(viewportFraction: .88);
  int _page = 0;
  String? _exploreSubject;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int i) =>
      _controller.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);

  void _complete(BuildContext context, Task task) {
    final state = context.read<AppState>();
    final reward = state.setTaskStatus(task, TaskStatus.completada);
    showRewardSnack(
      context,
      reward,
      message: '¡${task.subject} completada!',
      action: SnackBarAction(label: 'Deshacer', onPressed: () => state.setTaskStatus(task, TaskStatus.pendiente)),
    );
  }

  /// Si Inicio pidió abrir una ficha, salta a ella cuando el carrusel ya existe.
  void _openRequested(AppState state, List<_Ficha> fichas) {
    final key = state.suggestionRequest;
    if (key == null) return;
    state.clearSuggestionRequest();
    final i = fichas.indexWhere((f) => f.key == key);
    if (i < 0) return;
    _page = i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) _controller.jumpToPage(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = context.colors;
    final fichas = [
      ...[...state.pendingByDueDate.map(_Ficha.task), ...state.upcomingStudySessions().map(_Ficha.session)]
        ..sort((a, b) => a.when!.compareTo(b.when!)),
      _Ficha.explore(),
    ];
    _openRequested(state, fichas);
    if (_page >= fichas.length) _page = fichas.length - 1;
    final today = DateUtils.dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Sugerencias de estudio'), actions: const [ProfileButton()]),
      body: Column(
        children: [
          // Barra con todas las fichas
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: fichas.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final f = fichas[i];
                final (label, icon, color) = switch (f) {
                  _Ficha(:final task?) => ('${task.subject} · ${daysLeftLabel(task.daysLeft())}', null, null),
                  _Ficha(:final session?) => (
                    '${session.block.studySubject} · ${daysLeftLabel(session.day.difference(today).inDays)}',
                    BlockType.estudio.icon,
                    colors.estudio,
                  ),
                  _ => ('Explorar materia', Icons.travel_explore_rounded, null),
                };
                return ChoiceChip(
                  avatar: icon == null ? null : Icon(icon, size: 18, color: color),
                  // Las sesiones y "Explorar" conservan su ícono al quedar seleccionadas.
                  showCheckmark: icon == null,
                  label: Text(label),
                  selected: i == _page,
                  onSelected: (_) => _goTo(i),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: fichas.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final f = fichas[i];
                final position = i == 0 ? 'La más próxima' : '${i + 1} de ${fichas.length - 1}';
                final Widget card = switch (f) {
                  _Ficha(:final task?) => _SuggestionCard(
                    task: task,
                    position: position,
                    onComplete: () => _complete(context, task),
                    onStudy: () => state.startStudying(task),
                  ),
                  _Ficha(:final session?) => _SessionCard(session: session, position: position),
                  _ => _ExploreCard(
                    subject: _exploreSubject,
                    alone: fichas.length == 1,
                    onSubject: (s) => setState(() => _exploreSubject = s),
                  ),
                };
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    var delta = 0.0;
                    if (_controller.position.haveDimensions) {
                      delta = (_controller.page! - i).abs();
                    } else {
                      delta = (_page - i).abs().toDouble();
                    }
                    final scale = (1 - delta * .14).clamp(.82, 1.0);
                    final opacity = (1 - delta * .4).clamp(.5, 1.0);
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: card,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < fichas.length && i < 10; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marco común de las fichas: encabezado, cuerpo con scroll y botones abajo.
class _FichaFrame extends StatelessWidget {
  const _FichaFrame({required this.header, required this.body, this.actions});

  final List<Widget> header;
  final List<Widget> body;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Card(
      elevation: 3,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...header,
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
              ),
            ),
            if (actions != null) ...[const SizedBox(height: 12), actions!],
          ],
        ),
      ),
    ),
  );
}

/// Etiqueta de color arriba a la izquierda y posición en el carrusel a la derecha.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.label, required this.color, this.position});
  final String label;
  final Color color;
  final String? position;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Ocupa lo que necesita su texto y solo se recorta si no cabe.
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ),
      if (position != null) ...[
        const SizedBox(width: 8),
        Text(position!, style: Theme.of(context).textTheme.labelMedium),
      ],
    ],
  );
}

/// Botón principal de estudiar: el texto se acorta en pantallas angostas
/// para no partirse en dos líneas.
class _StudyButton extends StatelessWidget {
  const _StudyButton({required this.onPressed, this.color});
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(box.maxWidth < 210 ? 'Estudiar' : 'Empezar a estudiar', maxLines: 1),
        ),
      ),
    ),
  );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.task, required this.position, required this.onComplete, required this.onStudy});

  final Task task;
  final String position;
  final VoidCallback onComplete;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final days = task.daysLeft();
    final urgentColor = days <= 1 ? c.pending : (days <= task.complexity.daysAhead ? c.creative : c.success);
    final slot = state.nextSlotFor(task);

    return _FichaFrame(
      header: [
        _HeaderRow(label: task.complexity.label, color: scheme.primary, position: position),
        const SizedBox(height: 14),
        Text(task.subject, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        if (task.topic.isNotEmpty) Text(task.topic, style: t.titleMedium),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: urgentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${capitalize(shortDate(task.dueDate))} (${daysLeftLabel(days)})',
                style: TextStyle(color: urgentColor, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
      body: [
        Text(task.description.isEmpty ? 'Sin descripción.' : task.description, style: t.bodyLarge),
        const SizedBox(height: 14),
        _InfoRow(icon: Icons.insights_rounded, text: state.workloadHint(task)),
        const SizedBox(height: 6),
        _InfoRow(
          icon: Icons.schedule_rounded,
          text: slot == null
              ? 'Tu horario no tiene espacios libres antes de la entrega.'
              : 'Próximo espacio libre: ${slotLabel(slot.start, slot.end)}',
        ),
        const SizedBox(height: 6),
        _InfoRow(
          icon: Icons.timer_outlined,
          text: 'Sesión sugerida: ${state.planner.suggestedSessionMinutes(task)} min',
        ),
        const SizedBox(height: 18),
        StudyMaterialsSection.forTask(task),
      ],
      actions: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: IconButton.filled(
              tooltip: 'Ya la hice',
              style: IconButton.styleFrom(backgroundColor: c.success),
              onPressed: onComplete,
              icon: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _StudyButton(onPressed: onStudy)),
        ],
      ),
    );
  }
}

/// Ficha de una sesión de estudio autónomo: cuándo es, qué materia y tema,
/// cómo organizarla y material para esa materia y ese tema.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.position});
  final StudySession session;
  final String position;

  /// Próxima clase de la misma materia, para conectar el repaso con ella.
  static String? _nextClass(AppState state, String subject) {
    final name = subject.trim().toLowerCase();
    final classes = state.blocks.where((b) => b.type == BlockType.clase && b.title.trim().toLowerCase() == name);
    if (classes.isEmpty) return null;
    final now = DateTime.now();
    for (var i = 0; i <= 7; i++) {
      final day = DateUtils.addDaysToDate(DateUtils.dateOnly(now), i);
      final hits = classes.where((b) => b.weekday == day.weekday).toList()..sort((a, b) => a.start.compareTo(b.start));
      for (final b in hits) {
        final start = DateTime(day.year, day.month, day.day, b.start.hour, b.start.minute);
        if (start.isAfter(now)) return '${capitalize(shortDate(day))} a las ${b.start.format()}';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final b = session.block;
    final blue = context.colors.estudio;
    final t = Theme.of(context).textTheme;
    final minutes = b.durationMinutes;
    final today = DateUtils.dateOnly(DateTime.now());
    final days = session.day.difference(today).inDays;
    final nextClass = _nextClass(state, b.studySubject);
    final plan = minutes >= 90
        ? 'Divide los $minutes min en bloques de 50 min con 10 min de pausa.'
        : 'Haz bloques Pomodoro de 25 min con 5 min de pausa.';

    return _FichaFrame(
      header: [
        _HeaderRow(label: 'Estudio autónomo', color: blue, position: position),
        const SizedBox(height: 14),
        Text(b.studySubject, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        if (b.topic.isNotEmpty) Text(b.topic, style: t.titleMedium),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: blue),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${capitalize(shortDate(session.day))} (${daysLeftLabel(days)}) · ${b.start.format()} – ${b.end.format()}',
                style: TextStyle(color: blue, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
      body: [
        Text(
          b.topic.isEmpty
              ? 'Sesión para repasar ${b.studySubject} en general. Si eliges un tema al editarla, las recomendaciones se ajustan a él.'
              : 'Sesión para estudiar ${b.topic} de ${b.studySubject}.',
          style: t.bodyLarge,
        ),
        const SizedBox(height: 14),
        _InfoRow(icon: Icons.timer_outlined, text: 'Duración: ${_duration(minutes)}. $plan'),
        const SizedBox(height: 6),
        _InfoRow(
          icon: Icons.edit_note_rounded,
          text:
              'Empieza 10 min repasando tus apuntes de clase; luego practica con el material de abajo y cierra '
              'escribiendo 3 ideas clave.',
        ),
        if (nextClass != null) ...[
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.school_rounded,
            text: 'Tu próxima clase de ${b.studySubject}: $nextClass. Lleva tus dudas.',
          ),
        ],
        const SizedBox(height: 18),
        StudyMaterialsSection(subject: b.studySubject, topic: b.topic),
      ],
      actions: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: IconButton.filledTonal(
              tooltip: 'Editar materia, tema u horario',
              onPressed: () => showBlockForm(context, block: b),
              icon: const Icon(Icons.edit_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StudyButton(color: blue, onPressed: () => state.startStudySession(b)),
          ),
        ],
      ),
    );
  }

  static String _duration(int m) {
    final h = m ~/ 60;
    final r = m % 60;
    return [if (h > 0) '$h h', if (r > 0) '$r min'].join(' ');
  }
}

/// "Explorar una materia": elige una de las clases del calendario y trae todo
/// el material relacionado. Es la última ficha; si no hay pendientes, la única.
class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.subject, required this.alone, required this.onSubject});
  final String? subject;
  final bool alone;
  final ValueChanged<String?> onSubject;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final subjects = state.classSubjects;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final selected = subjects.contains(subject) ? subject : null;

    return _FichaFrame(
      header: [
        _HeaderRow(label: 'Autoestudio', color: scheme.tertiary),
        const SizedBox(height: 14),
        Text('Explorar una materia', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          alone
              ? '¡Estás al día! Aprovecha para estudiar por tu cuenta una de tus materias.'
              : 'Elige una materia de tu calendario y te mostramos todo el material relacionado.',
          style: t.bodyMedium,
        ),
      ],
      body: [
        if (subjects.isEmpty) ...[
          Text('Aún no tienes clases en el calendario.', style: t.bodyLarge),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => state.selectTab(AppTab.horario),
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Agregar clases'),
          ),
        ] else ...[
          DropdownMenu<String>(
            key: ValueKey(selected),
            initialSelection: selected,
            expandedInsets: EdgeInsets.zero,
            label: const Text('Materia'),
            leadingIcon: const Icon(Icons.menu_book_rounded),
            requestFocusOnTap: false,
            onSelected: onSubject,
            dropdownMenuEntries: [for (final s in subjects) DropdownMenuEntry(value: s, label: s)],
          ),
          const SizedBox(height: 18),
          if (selected == null)
            Text('Elige una materia para ver libros, videos y artículos.', style: t.bodyMedium)
          else
            StudyMaterialsSection(subject: selected, wholeSubject: true),
        ],
      ],
      actions: alone
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showTaskForm(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva tarea'),
              ),
            )
          : null,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.tertiary),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    ],
  );
}
