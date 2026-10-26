import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_block.dart';
import '../services/schedule_pdf_parser.dart';
import '../state/app_state.dart';

/// Muestra lo que se reconoció del PDF para que el usuario confirme antes de
/// insertarlo en el horario (puede desmarcar grupos que no le corresponden).
class ImportPreviewScreen extends StatefulWidget {
  const ImportPreviewScreen({super.key, required this.classes});
  final List<ParsedClass> classes;

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  late final List<bool> _selected = List.filled(widget.classes.length, true);
  bool _replace = true;

  int get _count => _selected.where((s) => s).length;

  void _import() {
    final chosen = [
      for (var i = 0; i < widget.classes.length; i++)
        if (_selected[i]) widget.classes[i],
    ];
    final n = context.read<AppState>().importClasses(chosen, replaceClasses: _replace);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se agregaron $n clases a tu horario')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasDuplicates =
        widget.classes.map((c) => c.code).toSet().length < widget.classes.length ||
        widget.classes.any((c) => c.group.isNotEmpty && c.group.contains('·'));
    return Scaffold(
      appBar: AppBar(title: const Text('Horario reconocido')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _count == 0 ? null : _import,
            icon: const Icon(Icons.download_done_rounded),
            label: Text('AGREGAR $_count CLASES AL HORARIO'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Encontré ${widget.classes.length} franjas de clase. Revisa y desmarca las que no tomes.',
            style: t.bodyMedium,
          ),
          if (hasDuplicates) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: .15),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Tu reporte trae varios grupos de una misma materia (por ejemplo, las líneas de profundización). '
                  'Deja marcados solo los que te corresponden.',
                ),
              ),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _replace,
            onChanged: (v) => setState(() => _replace = v),
            title: const Text('Reemplazar las clases que ya tenía'),
            subtitle: const Text('Ocio, trabajo y extracurriculares se conservan'),
          ),
          const Divider(),
          for (var i = 0; i < widget.classes.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected[i],
              onChanged: (v) => setState(() => _selected[i] = v ?? false),
              title: Text(widget.classes[i].title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                [
                  '${weekdayNames[widget.classes[i].weekday - 1]} '
                      '${widget.classes[i].start.format()} – ${widget.classes[i].end.format()}',
                  if (widget.classes[i].room.isNotEmpty) widget.classes[i].room,
                  if (widget.classes[i].teacher.isNotEmpty) widget.classes[i].teacher,
                  if (widget.classes[i].group.isNotEmpty) widget.classes[i].group,
                ].join('\n'),
              ),
              isThreeLine: true,
            ),
        ],
      ),
    );
  }
}
