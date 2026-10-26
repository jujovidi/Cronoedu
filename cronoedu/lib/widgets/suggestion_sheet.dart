import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/planner.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';
import 'mascot.dart';

/// Agenda la hora sugerida en el horario y lo confirma.
void scheduleSuggestion(BuildContext context, StudySuggestion s) {
  context.read<AppState>().scheduleSuggestion(s);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Agendado en tu horario: ${slotLabel(s.start, s.end)}')));
}

/// "Procrastinar": descarta la sugerencia de ese día.
void procrastinate(BuildContext context, StudySuggestion s) {
  final state = context.read<AppState>();
  state.dismissSuggestion(s);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Sugerencia descartada. ¡Mañana será!')));
}

/// Hoja con el espacio libre sugerido: agendar o procrastinar.
Future<void> showSuggestionSheet(BuildContext context, StudySuggestion s) {
  final c = context.colors;
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(MascotPose.enfoque, size: 70),
            const SizedBox(height: 8),
            Text(
              'Espacio libre para estudiar',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              slotLabel(s.start, s.end),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.success),
            ),
            const SizedBox(height: 6),
            const Text(
              'Si lo agendas, queda en tu horario como sesión de estudio autónomo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      procrastinate(context, s);
                    },
                    icon: const Icon(Icons.snooze_rounded),
                    label: const Text('Procrastinar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      scheduleSuggestion(context, s);
                    },
                    icon: const Icon(Icons.event_available_rounded),
                    label: const Text('Agendar'),
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
