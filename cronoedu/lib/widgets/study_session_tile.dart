import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_block.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Sesión de estudio autónomo en la lista del día (azul, como en el
/// calendario). Tocarla abre su ficha con recomendaciones en Sugerencias.
class StudySessionTile extends StatelessWidget {
  const StudySessionTile(this.session, {super.key});
  final StudySession session;

  @override
  Widget build(BuildContext context) {
    final b = session.block;
    final blue = context.colors.estudio;
    final t = Theme.of(context).textTheme;
    final ended = session.end.isBefore(DateTime.now());

    return Card(
      clipBehavior: Clip.antiAlias,
      color: Color.alphaBlend(blue.withValues(alpha: .14), Theme.of(context).colorScheme.surface),
      child: InkWell(
        onTap: ended ? null : () => context.read<AppState>().openSuggestion('sesion:${b.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: blue),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(BlockType.estudio.icon, color: blue, size: 28),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(b.studySubject, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      if (b.topic.isNotEmpty) Text(b.topic, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Pill('Estudio autónomo', blue),
                          _Pill('${b.start.format()} – ${b.end.format()}', blue),
                          if (ended) _Pill('Terminada', Theme.of(context).colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!ended)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right_rounded, color: blue),
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
    decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}
