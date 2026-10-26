import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task.dart';
import '../services/study_links.dart';
import '../services/study_material_repository.dart';
import '../state/app_state.dart';

/// "Material para estudiar": hasta 3 libros o atlas de las bibliotecas de la
/// universidad, 2 videos y 3 artículos sobre la materia y el tema de la tarea.
class StudyMaterialsSection extends StatefulWidget {
  const StudyMaterialsSection({super.key, required this.task});
  final Task task;

  @override
  State<StudyMaterialsSection> createState() => _StudyMaterialsSectionState();
}

class _StudyMaterialsSectionState extends State<StudyMaterialsSection> {
  Future<List<StudyMaterial>>? _future;
  String? _query;

  void _search() {
    final task = widget.task;
    final career = context.read<AppState>().profile.career;
    final query = '${task.subject}|${task.topic}|${task.description}|$career';
    if (query == _query) return;
    _query = query;
    _future = StudyMaterialLibrary.instance.forTask(
      subject: task.subject,
      topic: task.topic,
      description: task.description,
      career: career,
    );
  }

  @override
  Widget build(BuildContext context) {
    _search();
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<StudyMaterial>>(
      future: _future,
      builder: (context, snap) {
        final list = snap.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Material para estudiar', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Biblioteca de la universidad', style: t.labelLarge),
            if (snap.hasError)
              Text('No pudimos abrir el catálogo de material.', style: t.bodySmall)
            else if (list == null)
              Text('Buscando en las bibliotecas de la universidad…', style: t.bodySmall)
            else if (list.isEmpty)
              Text(
                'No hay libros de la biblioteca sobre este tema. Prueba escribiéndolo con otras palabras.',
                style: t.bodySmall,
              )
            else
              for (final m in list) _MaterialTile(material: m),
            for (final kind in StudyLinkKind.values) ...[
              const SizedBox(height: 10),
              Text(kind == StudyLinkKind.video ? 'Videos' : 'Artículos', style: t.labelLarge),
              for (final link in StudyLinks.forTask(widget.task).where((l) => l.kind == kind)) _LinkTile(link: link),
            ],
          ],
        );
      },
    );
  }
}

Future<void> _openUrl(BuildContext context, Uri url) async {
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace.')));
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link});
  final StudyLink link;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final video = link.kind == StudyLinkKind.video;
    return Card(
      margin: const EdgeInsets.only(top: 6),
      color: scheme.surfaceContainerHighest.withValues(alpha: .6),
      elevation: 0,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          video ? Icons.smart_display_rounded : Icons.article_rounded,
          color: video ? const Color(0xFFE5484D) : scheme.tertiary,
        ),
        title: Text(link.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(link.source),
        trailing: Icon(Icons.open_in_new_rounded, size: 20, color: scheme.primary),
        onTap: () => _openUrl(context, link.url),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.material});
  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = material.url(eniBaseUrl: StudyMaterialLibrary.eniBaseUrl);
    final details = [material.source, if (material.year != null) '${material.year}'].join(' · ');
    return Card(
      margin: const EdgeInsets.only(top: 6),
      color: scheme.surfaceContainerHighest.withValues(alpha: .6),
      elevation: 0,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(material.isAtlas ? Icons.view_in_ar_rounded : Icons.menu_book_rounded, color: scheme.primary),
        title: Text(material.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(url == null ? '$details\nBúscalo en la biblioteca con tu cuenta institucional' : details),
        isThreeLine: url == null,
        trailing: url == null ? null : Icon(Icons.open_in_new_rounded, size: 20, color: scheme.primary),
        onTap: url == null ? null : () => _openUrl(context, Uri.parse(url)),
      ),
    );
  }
}
