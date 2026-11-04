import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Material de estudio de las bases de la universidad (ENI, AlphaCloud,
/// Eureka, BioAtlas, BioAtlasVet). Viene dentro de la app en
/// assets/data/material_estudio.json.gz (lo genera tool/compactar_material.py).
class StudyMaterial {
  StudyMaterial.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      source = j['fuente'] as String,
      type = (j['tipo'] as String?) ?? '',
      title = j['titulo'] as String,
      authors = List<String>.from(j['autores'] as List? ?? const []),
      year = j['anio'] as int?,
      subcategory = j['subcategoria'] as String?,
      programs = List<String>.from(j['programas'] as List? ?? const []),
      rawUrl = j['url'] as String?,
      urlNeedsBase = (j['url_requiere_base'] as bool?) ?? false,
      _title = _set(j['idx_titulo']),
      _topics = _set(j['idx_temas']),
      _summary = _set(j['idx_resumen']);

  final String id;
  final String source;
  final String type;
  final String title;
  final List<String> authors;
  final int? year;
  final String? subcategory;
  final List<String> programs;

  /// URL tal como viene en el catálogo. Las de ENI traen `%SITE_CLIENT%`,
  /// que se reemplaza con la URL base de la biblioteca de la universidad.
  final String? rawUrl;
  final bool urlNeedsBase;

  final Set<String> _title;
  final Set<String> _topics;
  final Set<String> _summary;

  bool get isAtlas => type.contains('atlas');

  String? url({String? eniBaseUrl}) {
    final u = rawUrl;
    if (u == null || !urlNeedsBase) return u;
    return eniBaseUrl == null || eniBaseUrl.isEmpty ? null : u.replaceFirst('%SITE_CLIENT%', eniBaseUrl);
  }

  static Set<String> _set(Object? s) => (s as String? ?? '').split(' ').where((t) => t.isNotEmpty).toSet();
}

class StudyMaterialResult {
  const StudyMaterialResult(this.material, this.score);
  final StudyMaterial material;
  final double score;
}

/// Índice de búsqueda offline. Mismo algoritmo que `buscar.py`:
/// tokens normalizados, peso por campo (título 3, temas 2, resumen 1) × IDF,
/// coincidencia por prefijo a mitad de peso, sinónimos a 0,7 y premios por
/// cubrir varias palabras, por título centrado en el tema y por la carrera.
class StudyMaterialIndex {
  StudyMaterialIndex._(this.version, this.materials, this._stopwords, this._synonyms) {
    for (final m in materials) {
      for (final t in {...m._title, ...m._topics, ...m._summary}) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
    _idfMax = math.log(1 + materials.length);
  }

  /// [catalogJson] = el JSON del catálogo; trae los sinónimos en "sinonimos".
  factory StudyMaterialIndex.fromJson(String catalogJson) {
    final data = jsonDecode(catalogJson) as Map<String, dynamic>;
    final index = StudyMaterialIndex._(
      data['version'] as String,
      [for (final m in data['materiales'] as List) StudyMaterial.fromJson(m as Map<String, dynamic>)],
      Set<String>.from(data['stopwords'] as List),
      {},
    );
    (data['sinonimos'] as Map<String, dynamic>? ?? const {}).forEach((word, extras) {
      for (final t in index.tokenize(word)) {
        index._synonyms.putIfAbsent(t, () => []).addAll([
          for (final e in extras as List) ...index.tokenize(e as String),
        ]);
      }
    });
    return index;
  }

  /// Lee el catálogo comprimido con gzip.
  factory StudyMaterialIndex.fromGzip(List<int> bytes) => StudyMaterialIndex.fromJson(utf8.decode(gzip.decode(bytes)));

  final String version;
  final List<StudyMaterial> materials;
  final Set<String> _stopwords;
  final Map<String, List<String>> _synonyms;
  final Map<String, int> _df = {};
  late final double _idfMax;

  static const _weights = (title: 3.0, topics: 2.0, summary: 1.0);
  static const _accents = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  static final _nonWord = RegExp(r'[^a-z0-9+#]+');
  static final _looseNumber = RegExp(r'(?<![\w.])\d+(?![\w.])');

  /// Normaliza igual que `tokens()` en construir_base.py.
  List<String> tokenize(String text) {
    final buf = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      buf.write(_accents[ch] ?? ch);
    }
    final out = <String>[];
    for (final t in buf.toString().replaceAll(_nonWord, ' ').split(' ')) {
      if (t.isEmpty || _stopwords.contains(t) || (t.length < 2 && int.tryParse(t) == null)) continue;
      final r = _stem(t);
      if (!out.contains(r)) out.add(r);
    }
    return out;
  }

  static String _stem(String t) {
    var s = t;
    if (s.length > 3 && s.endsWith('s')) s = s.substring(0, s.length - 1);
    if (s.length > 3 && 'aeo'.contains(s[s.length - 1])) s = s.substring(0, s.length - 1);
    return s;
  }

  double _idf(String t) {
    final d = _df[t];
    return d == null ? _idfMax : math.log(1 + materials.length / d);
  }

  double _tokenWeight(String q, StudyMaterial m) {
    var best = 0.0;
    for (final (field, weight) in [
      (m._title, _weights.title),
      (m._topics, _weights.topics),
      (m._summary, _weights.summary),
    ]) {
      if (field.contains(q)) {
        best = math.max(best, weight * _idf(q));
      } else if (q.length >= 4) {
        for (final t in field) {
          if (t.length >= 4 && (t.startsWith(q) || q.startsWith(t))) {
            best = math.max(best, 0.5 * weight * _idf(t));
            break;
          }
        }
      }
    }
    return best;
  }

  /// Busca material relacionado con [query]. [program] (la carrera del
  /// perfil) da un 30 % extra al material de esa carrera.
  List<StudyMaterialResult> search(String query, {String? program, int limit = 5}) {
    final qs = tokenize(query);
    final expanded = <String, double>{for (final q in qs) q: 1.0};
    for (final q in qs) {
      for (final s in _synonyms[q] ?? const <String>[]) {
        expanded.putIfAbsent(s, () => 0.7);
      }
    }
    if (expanded.isEmpty) return const [];
    final prog = tokenize(program ?? '').toSet();
    final results = <StudyMaterialResult>[];
    for (final m in materials) {
      var score = 0.0;
      var hits = 0;
      expanded.forEach((q, factor) {
        final w = _tokenWeight(q, m);
        if (w > 0) {
          score += factor * w;
          hits++;
        }
      });
      if (score == 0) continue;
      score *= 1 + 0.5 * (hits - 1) / math.max(1, expanded.length);
      if (m._title.isNotEmpty) {
        final covered = m._title.where(expanded.containsKey).length;
        score *= 1 + 0.4 * covered / m._title.length;
      }
      if (prog.isNotEmpty &&
          prog.intersection(tokenize([...m.programs, m.subcategory ?? ''].join(' ')).toSet()).isNotEmpty) {
        score *= 1.3;
      }
      results.add(StudyMaterialResult(m, score));
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  /// Sugerencias para una tarea: la materia y el tema pesan más que la descripción.
  List<StudyMaterialResult> forTask({
    required String subject,
    String topic = '',
    String description = '',
    String? career,
    int limit = 5,
  }) {
    // Los números sueltos ("Taller 3", "ejercicios 1 a 10") no dicen nada
    // del tema y harían salir libros como "Python 3" o "Windows 10".
    String clean(String s) => s.replaceAll(_looseNumber, ' ');
    final pool = math.max(50, limit);
    final main = search(clean('$subject $topic'), program: career, limit: pool);
    if (description.trim().isEmpty) return main.take(limit).toList();
    final extra = {for (final r in search(clean(description), program: career, limit: pool)) r.material.id: r.score};
    final merged = [for (final r in main) StudyMaterialResult(r.material, r.score + 0.5 * (extra[r.material.id] ?? 0))]
      ..sort((a, b) => b.score.compareTo(a.score));
    return merged.take(limit).toList();
  }
}

/// Carga el catálogo una sola vez (en segundo plano) y lo comparte.
class StudyMaterialLibrary {
  StudyMaterialLibrary._();
  static final instance = StudyMaterialLibrary._();

  static const asset = 'assets/data/material_estudio.json.gz';

  /// URL base de la biblioteca ENI de la universidad. Mientras esté vacía,
  /// los libros de ENI se muestran sin enlace.
  static const eniBaseUrl = '';

  Future<StudyMaterialIndex>? _index;

  /// Para pruebas: reemplaza el catálogo por uno ya cargado.
  @visibleForTesting
  set debugIndex(StudyMaterialIndex? index) => _index = index == null ? null : Future.value(index);

  Future<StudyMaterialIndex> get index => _index ??= _load();

  static Future<StudyMaterialIndex> _load() async {
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return Isolate.run(() => StudyMaterialIndex.fromGzip(bytes));
  }

  /// Hasta [limit] materiales para una tarea (materia, tema y descripción),
  /// dando prioridad a los de la carrera del perfil.
  Future<List<StudyMaterial>> forTask({
    required String subject,
    String topic = '',
    String description = '',
    String? career,
    int limit = 3,
    double relative = .5,
  }) async {
    final idx = await index;
    final results = idx.forTask(subject: subject, topic: topic, description: description, career: career, limit: limit);
    if (results.isEmpty) return const [];
    // Solo coincidencias claras: mejor no sugerir nada que sugerir un libro
    // que no tiene que ver (p. ej. "Docker" para Microbiología).
    final top = results.first.score;
    return [
      for (final r in results)
        if (r.score >= minScore && r.score >= relative * top) r.material,
    ];
  }

  /// Todo el material relacionado con una materia (para estudiarla completa).
  /// Acepta coincidencias más amplias que [forTask], sin bajar de [minScore].
  Future<List<StudyMaterial>> forSubject(String subject, {String? career}) =>
      forTask(subject: subject, career: career, limit: 200, relative: .3);

  /// Puntaje mínimo para mostrar un material (los buenos suelen pasar de 15).
  static const minScore = 12.0;
}
