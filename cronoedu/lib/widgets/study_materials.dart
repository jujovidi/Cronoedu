import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/task.dart';
import '../services/study_links.dart';
import '../services/study_material_repository.dart';
import '../state/app_state.dart';

/// "Material para estudiar": libros o atlas de las bibliotecas de la
/// universidad, videos y artículos. Para una tarea o sesión trae lo más
/// cercano a la materia y el tema; con [wholeSubject] trae todo lo
/// relacionado con la materia, de a [pageSize] con "Ver más".
class StudyMaterialsSection extends StatefulWidget {
  const StudyMaterialsSection({
    super.key,
    required this.subject,
    this.topic = '',
    this.description = '',
    this.wholeSubject = false,
  });

  StudyMaterialsSection.forTask(Task task, {Key? key})
    : this(key: key, subject: task.subject, topic: task.topic, description: task.description);

  final String subject;
  final String topic;
  final String description;
  final bool wholeSubject;

  static const pageSize = 10;

  @override
  State<StudyMaterialsSection> createState() => _StudyMaterialsSectionState();
}

class _StudyMaterialsSectionState extends State<StudyMaterialsSection> {
  Future<List<StudyMaterial>>? _future;
  String? _query;
  int _shown = StudyMaterialsSection.pageSize;

  void _search() {
    final w = widget;
    final career = context.read<AppState>().profile.career;
    final query = '${w.subject}|${w.topic}|${w.description}|${w.wholeSubject}|$career';
    if (query == _query) return;
    _query = query;
    _shown = StudyMaterialsSection.pageSize;
    final library = StudyMaterialLibrary.instance;
    _future = w.wholeSubject
        ? library.forSubject(w.subject, career: career)
        : library.forTask(subject: w.subject, topic: w.topic, description: w.description, career: career);
  }

  @override
  Widget build(BuildContext context) {
    _search();
    final t = Theme.of(context).textTheme;
    final links = widget.wholeSubject
        ? StudyLinks.forSubject(widget.subject)
        : StudyLinks.forTopic(widget.subject, widget.topic);
    return FutureBuilder<List<StudyMaterial>>(
      future: _future,
      builder: (context, snap) {
        final list = snap.data;
        final visible = list == null ? const <StudyMaterial>[] : list.take(_shown).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Material para estudiar', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              list != null && list.isNotEmpty && widget.wholeSubject
                  ? 'Biblioteca de la universidad · ${list.length} ${list.length == 1 ? 'resultado' : 'resultados'}'
                  : 'Biblioteca de la universidad',
              style: t.labelLarge,
            ),
            if (snap.hasError)
              Text('No pudimos abrir el catálogo de material.', style: t.bodySmall)
            else if (list == null)
              Text('Buscando en las bibliotecas de la universidad…', style: t.bodySmall)
            else if (list.isEmpty)
              Text(
                'No hay libros de la biblioteca sobre este tema. Prueba escribiéndolo con otras palabras.',
                style: t.bodySmall,
              )
            else ...[
              for (final m in visible) _MaterialTile(material: m),
              if (list.length > visible.length)
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _shown += StudyMaterialsSection.pageSize),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text('Ver más (${list.length - visible.length} restantes)'),
                  ),
                ),
            ],
            for (final kind in StudyLinkKind.values) ...[
              const SizedBox(height: 14),
              Text(kind == StudyLinkKind.video ? 'Videos' : 'Artículos', style: t.labelLarge),
              for (final link in links.where((l) => l.kind == kind)) _LinkTile(link: link),
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

/// Tarjeta de material: ícono en un recuadro, título de hasta 3 líneas y fuente.
class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: scheme.surfaceContainerHighest.withValues(alpha: .6),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: t.bodySmall),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.open_in_new_rounded, size: 22, color: scheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link});
  final StudyLink link;

  @override
  Widget build(BuildContext context) {
    final video = link.kind == StudyLinkKind.video;
    return _MaterialCard(
      icon: video ? Icons.smart_display_rounded : Icons.article_rounded,
      iconColor: video ? const Color(0xFFE5484D) : Theme.of(context).colorScheme.tertiary,
      title: link.title,
      subtitle: link.source,
      onTap: () => _openUrl(context, link.url),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.material});
  final StudyMaterial material;

  @override
  Widget build(BuildContext context) {
    final url = material.url(eniBaseUrl: StudyMaterialLibrary.eniBaseUrl);
    final details = [material.source, if (material.year != null) '${material.year}'].join(' · ');
    return _MaterialCard(
      icon: material.isAtlas ? Icons.view_in_ar_rounded : Icons.menu_book_rounded,
      iconColor: Theme.of(context).colorScheme.primary,
      title: material.title,
      subtitle: url == null ? '$details\nBúscalo en la biblioteca con tu cuenta institucional' : details,
      onTap: url == null ? null : () => _openUrl(context, Uri.parse(url)),
    );
  }
}
