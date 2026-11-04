import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';
import 'reward_feedback.dart';
import 'task_form.dart';

/// Tarea en lista: rojo = pendiente, verde = completada. Tocar el círculo
/// cambia el estado; el menú permite editar o eliminar. Tocar una pendiente
/// abre su ficha en Sugerencias.
class TaskTile extends StatelessWidget {
  const TaskTile(this.task, {super.key, this.showDate = false});

  final Task task;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = context.read<AppState>();
    final color = task.isPending ? colors.pending : colors.success;
    final t = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: task.isPending ? () => state.openSuggestion('tarea:${task.id}') : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              IconButton(
                tooltip: task.isPending ? 'Marcar como completada' : 'Marcar como pendiente',
                onPressed: () {
                  final wasPending = task.isPending;
                  final reward = state.toggleTask(task);
                  if (wasPending) showRewardSnack(context, reward, message: '¡${task.subject} completada!');
                },
                icon: Icon(
                  task.isPending ? Icons.radio_button_unchecked_rounded : Icons.check_circle_rounded,
                  color: color,
                  size: 28,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        task.subject,
                        style: t.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task.topic.isNotEmpty)
                        Text(task.topic, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (task.description.isNotEmpty)
                        Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Pill(task.isPending ? 'Pendiente' : 'Completada', color),
                          _Pill(task.complexity.label, Theme.of(context).colorScheme.primary),
                          if (task.dueTime != null) _Pill('Entrega ${task.dueTime!.format()}', colors.focus),
                          if (task.delivery == DeliveryMode.fisico) _Pill('En físico', colors.creative),
                          if (showDate)
                            _Pill(
                              '${shortDate(task.dueDate)} · ${daysLeftLabel(task.daysLeft())}',
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    showTaskForm(context, task: task);
                  } else if (v == 'delete') {
                    final ok = await confirmDelete(context, '¿Eliminar la tarea de ${task.subject}?');
                    if (ok) state.deleteTask(task);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(20)),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String message, {String confirm = 'Eliminar'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
