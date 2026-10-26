import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import '../widgets/mascot.dart';
import '../widgets/reward_feedback.dart';
import '../widgets/study_materials.dart';
import '../widgets/task_form.dart';
import 'shell.dart';

/// Sugerencias de estudio: carrusel con las tareas pendientes ordenadas por
/// fecha de entrega. La actual se ve grande; al deslizar se encoge y aparece
/// la siguiente (o la anterior hacia el otro lado).
class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  final _controller = PageController(viewportFraction: .84);
  int _page = 0;

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.pendingByDueDate;
    if (_page >= tasks.length && tasks.isNotEmpty) _page = tasks.length - 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Sugerencias de estudio'), actions: const [ProfileButton()]),
      body: tasks.isEmpty
          ? Center(
              child: EmptyState(
                pose: MascotPose.logro,
                title: '¡Estás al día!',
                message: 'No tienes tareas pendientes. Cuando agregues una, aquí te diremos cuándo trabajarla.',
                action: FilledButton.icon(
                  onPressed: () => showTaskForm(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nueva tarea'),
                ),
              ),
            )
          : Column(
              children: [
                // Barra con todas las pendientes
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) => ChoiceChip(
                      label: Text('${tasks[i].subject} · ${daysLeftLabel(tasks[i].daysLeft())}'),
                      selected: i == _page,
                      onSelected: (_) => _goTo(i),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: tasks.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => AnimatedBuilder(
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
                      child: _SuggestionCard(
                        task: tasks[i],
                        index: i,
                        total: tasks.length,
                        onComplete: () => _complete(context, tasks[i]),
                        onStudy: () => state.startStudying(tasks[i]),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < tasks.length && i < 10; i++)
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

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.task,
    required this.index,
    required this.total,
    required this.onComplete,
    required this.onStudy,
  });

  final Task task;
  final int index;
  final int total;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Card(
        elevation: 3,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      task.complexity.label,
                      style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  Text(index == 0 ? 'La más próxima' : '${index + 1} de $total', style: t.labelMedium),
                ],
              ),
              const SizedBox(height: 14),
              Text(task.subject, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
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
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 16),
                      StudyMaterialsSection(task: task),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
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
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: onStudy,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('EMPEZAR A ESTUDIAR'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
