import '../models/task.dart';

enum StudyLinkKind { video, articulo }

/// Enlace de apoyo para una tarea: abre una búsqueda ya armada con la
/// materia y el tema (YouTube, Google Académico, SciELO o Wikipedia).
class StudyLink {
  const StudyLink(this.kind, this.title, this.source, this.url);

  final StudyLinkKind kind;
  final String title;
  final String source;
  final Uri url;
}

/// Arma 2 videos y 3 artículos para una tarea. No necesita internet para
/// armarlos: son búsquedas con las palabras de la tarea, así siempre hay
/// resultados recientes aunque el tema sea muy específico.
class StudyLinks {
  /// Palabras que describen el tipo de entrega y no el tema.
  static const _generic = {
    'taller',
    'talleres',
    'quiz',
    'parcial',
    'examen',
    'entrega',
    'avance',
    'proyecto',
    'final',
    'tarea',
    'trabajo',
    'actividad',
    'ejercicio',
    'ejercicios',
    'primer',
    'primera',
    'segundo',
    'segunda',
    'tercer',
    'tercera',
    'corte',
    'informe',
    'exposicion',
    'exposición',
    'lectura',
    'guia',
    'guía',
    'punto',
    'puntos',
    'semana',
    'unidad',
    'grupal',
    'individual',
    'evaluacion',
    'evaluación',
    'sustentacion',
    'sustentación',
  };

  /// "Modelación · Taller 3" → "Modelación".
  static String query(Task task) => queryFor(task.subject, task.topic);

  static String queryFor(String subject, String topic) {
    final words = '$subject $topic'
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && int.tryParse(w) == null && !_generic.contains(w.toLowerCase()))
        .toList();
    return words.isEmpty ? subject.trim() : words.join(' ');
  }

  static List<StudyLink> forTask(Task task) => forTopic(task.subject, task.topic);

  /// 2 videos y 3 artículos sobre una materia y un tema (tareas y sesiones).
  static List<StudyLink> forTopic(String subject, String topic) {
    final q = queryFor(subject, topic);
    return [
      StudyLink(StudyLinkKind.video, 'Explicación de $q', 'YouTube', _youtube('$q explicación')),
      StudyLink(StudyLinkKind.video, '$q: ejercicios resueltos', 'YouTube', _youtube('$q ejercicios resueltos')),
      StudyLink(
        StudyLinkKind.articulo,
        'Artículos académicos sobre $q',
        'Google Académico',
        Uri.https('scholar.google.com', '/scholar', {'hl': 'es', 'q': q}),
      ),
      StudyLink(
        StudyLinkKind.articulo,
        'Artículos de revistas sobre $q',
        'SciELO',
        Uri.https('search.scielo.org', '/', {'q': q, 'lang': 'es'}),
      ),
      StudyLink(
        StudyLinkKind.articulo,
        'Conceptos básicos de $q',
        'Wikipedia',
        Uri.https('es.wikipedia.org', '/w/index.php', {'search': q}),
      ),
    ];
  }

  /// Para estudiar una materia completa: más videos y artículos de varias
  /// bases académicas que abren sin verificación anti-bots.
  static List<StudyLink> forSubject(String subject) {
    final q = queryFor(subject, '');
    return [
      StudyLink(StudyLinkKind.video, 'Curso completo de $q', 'YouTube', _youtube('$q curso completo')),
      StudyLink(StudyLinkKind.video, 'Explicación de $q', 'YouTube', _youtube('$q explicación')),
      StudyLink(StudyLinkKind.video, '$q: ejercicios resueltos', 'YouTube', _youtube('$q ejercicios resueltos')),
      StudyLink(
        StudyLinkKind.articulo,
        'Artículos académicos sobre $q',
        'Google Académico',
        Uri.https('scholar.google.com', '/scholar', {'hl': 'es', 'q': q}),
      ),
      StudyLink(
        StudyLinkKind.articulo,
        'Revisiones y estado del arte de $q',
        'Google Académico',
        Uri.https('scholar.google.com', '/scholar', {'hl': 'es', 'q': '$q revisión estado del arte'}),
      ),
      StudyLink(
        StudyLinkKind.articulo,
        'Artículos de revistas sobre $q',
        'SciELO',
        Uri.https('search.scielo.org', '/', {'q': q, 'lang': 'es'}),
      ),
      StudyLink(
        StudyLinkKind.articulo,
        'Revistas latinoamericanas sobre $q',
        'Redalyc',
        Uri.https('www.redalyc.org', '/busquedaArticuloFiltros.oa', {'q': q}),
      ),
      StudyLink(
        StudyLinkKind.articulo,
        'Artículos y tesis sobre $q',
        'Dialnet',
        Uri.https('dialnet.unirioja.es', '/buscar/documentos', {'querysDismax.DOCUMENTAL_TODO': q}),
      ),
      StudyLink(
        StudyLinkKind.articulo,
        'Conceptos básicos de $q',
        'Wikipedia',
        Uri.https('es.wikipedia.org', '/w/index.php', {'search': q}),
      ),
    ];
  }

  static Uri _youtube(String q) => Uri.https('www.youtube.com', '/results', {'search_query': q});
}
