import '../models/schedule_block.dart';

/// Palabra extraída de un PDF con su posición en la página (en puntos).
class PdfWord {
  const PdfWord(this.text, this.left, this.top, this.right, this.bottom);
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;
}

/// Clase reconocida en el reporte de horario.
class ParsedClass {
  ParsedClass({
    required this.code,
    required this.title,
    required this.weekday,
    required this.start,
    required this.end,
    this.room = '',
    this.teacher = '',
    this.group = '',
  });

  final String code;
  final String title;
  final int weekday;
  final DayTime start;
  final DayTime end;
  final String room;
  final String teacher;
  final String group;

  @override
  String toString() => '$title (${weekdayNames[weekday - 1]} ${start.format()}-${end.format()} $room)';
}

class ScheduleParseException implements Exception {
  ScheduleParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lee el "reporteHorario" oficial (Academusoft 4.0, Universidad de
/// Cundinamarca). El reporte es una tabla: la primera columna trae el código y
/// nombre del campo de aprendizaje, y cada columna de día trae la franja
/// horaria, el salón y el documento del docente. Como el texto del PDF no trae
/// la tabla, se reconstruye por posición: la columna del día se toma de la
/// coordenada X del encabezado (Lunes ... Domingo) y la materia de la fila en
/// la que cae la franja (coordenada Y).
class SchedulePdfParser {
  static final _timeRange = RegExp(r'^(\d{1,2}:\d{2})-(\d{1,2}:\d{2})$');
  static final _courseCode = RegExp(r'^\[?[A-Z]{2,}\d{4,}(-[A-Z0-9]+)?\]?$');
  static final _numeric = RegExp(r'^\d{5,}$');

  static const _dayHeaders = {
    'lunes': 1,
    'martes': 2,
    'miércoles': 3,
    'miercoles': 3,
    'jueves': 4,
    'viernes': 5,
    'sábado': 6,
    'sabado': 6,
    'domingo': 7,
  };

  List<ParsedClass> parse(List<PdfWord> words) {
    final lines = _groupLines(words);

    // 1. Encabezado con los días.
    final header = lines.firstWhere(
      (l) => l.where((w) => _dayHeaders.containsKey(w.text.toLowerCase())).length >= 5,
      orElse: () => throw ScheduleParseException(
        'No encontré la tabla de horario (fila Lunes ... Domingo). '
        '¿Es el reporte oficial de horario?',
      ),
    );
    final dayCenters = <int, double>{
      for (final w in header)
        if (_dayHeaders.containsKey(w.text.toLowerCase())) _dayHeaders[w.text.toLowerCase()]!: w.centerX,
    };
    final headerY = header.first.top;
    final firstDayLeft = dayCenters.values.reduce((a, b) => a < b ? a : b);
    final dayWidth = _minGap(dayCenters.values.toList());
    final courseColumnRight = firstDayLeft - dayWidth / 2;

    // 2. Docentes: "documento  nombre".
    final teachers = _readTeachers(lines, headerY);

    // 3. Filas de la columna "Campo de aprendizaje".
    final body = lines.where((l) => l.first.top > headerY + 2).toList();
    final courses = <_Course>[];
    _Course? current;
    var expectGroupNext = false;
    for (final line in body) {
      final left = line.where((w) => w.centerX < courseColumnRight).toList();
      if (left.isEmpty) continue;
      final text = left.map((w) => w.text).join(' ').trim();
      final first = left.first.text;

      if (expectGroupNext && current != null) {
        current.group = text;
        expectGroupNext = false;
        continue;
      }
      if (first.startsWith('[')) {
        current = _Course(left.first.top)..inParent = true;
        current.code = first.replaceAll(RegExp(r'[\[\]]'), '');
        courses.add(current);
        current.parentName.addAll(left.skip(1).map((w) => w.text));
        if (text.contains(']')) current.inParent = false;
        continue;
      }
      if (current != null && current.inParent) {
        current.parentName.addAll(left.map((w) => w.text));
        if (text.contains(']')) current.inParent = false;
        continue;
      }
      if (_courseCode.hasMatch(first) && left.length == 1) {
        if (current == null || current.group.isNotEmpty || current.hasGroupLabel) {
          current = _Course(left.first.top)..code = first;
          courses.add(current);
        } else {
          current.code = first; // sub-código de un grupo ([CAD...] → CAD...-A)
        }
        continue;
      }
      if (current == null) continue;
      final groupIdx = left.indexWhere((w) => w.text.toLowerCase() == 'grupo');
      if (groupIdx >= 0) {
        current.name.addAll(left.take(groupIdx).map((w) => w.text));
        current.hasGroupLabel = true;
        final after = left.skip(groupIdx + 1).map((w) => w.text).where((t) => t != ':').join(' ');
        if (after.isEmpty) {
          expectGroupNext = true;
        } else {
          current.group = after;
        }
        continue;
      }
      current.name.addAll(left.map((w) => w.text));
    }
    if (courses.isEmpty) {
      throw ScheduleParseException('No encontré materias en el reporte.');
    }

    // 4. Franjas horarias en las columnas de los días.
    final dayWords = <int, List<PdfWord>>{};
    for (final line in body) {
      for (final w in line) {
        if (w.centerX < courseColumnRight) continue;
        final day = _nearestDay(w.centerX, dayCenters);
        dayWords.putIfAbsent(day, () => []).add(w);
      }
    }

    final result = <ParsedClass>[];
    for (final entry in dayWords.entries) {
      final col = entry.value..sort((a, b) => a.top.compareTo(b.top));
      for (var i = 0; i < col.length; i++) {
        final m = _timeRange.firstMatch(col[i].text);
        if (m == null) continue;
        final course = courses.lastWhere((c) => c.top <= col[i].top + 4, orElse: () => courses.first);
        String room = '';
        String teacherId = '';
        for (var j = i + 1; j < col.length && j <= i + 2; j++) {
          final t = col[j].text;
          if (_timeRange.hasMatch(t)) break;
          if (_numeric.hasMatch(t) || t == 'DO') {
            teacherId = t;
          } else if (room.isEmpty) {
            room = t;
          }
        }
        result.add(
          ParsedClass(
            code: course.code,
            title: course.title,
            weekday: entry.key,
            start: _roundUp(DayTime.parse(m.group(1)!)),
            end: _roundUp(DayTime.parse(m.group(2)!)),
            room: room == 'RE' ? '' : room,
            teacher: teachers[teacherId] ?? '',
            group: course.groupLabel,
          ),
        );
      }
    }
    if (result.isEmpty) {
      throw ScheduleParseException('El reporte no tiene franjas horarias asignadas.');
    }
    result.sort((a, b) {
      final d = a.weekday.compareTo(b.weekday);
      return d != 0 ? d : a.start.compareTo(b.start);
    });
    return result;
  }

  Map<String, String> _readTeachers(List<List<PdfWord>> lines, double headerY) {
    final map = <String, String>{};
    var inside = false;
    for (final l in lines) {
      if (l.first.top >= headerY) break;
      final text = l.map((w) => w.text).join(' ').toLowerCase();
      if (text.contains('listado de docentes')) {
        inside = true;
        continue;
      }
      if (text.startsWith('listado de')) inside = false;
      if (!inside || l.length < 2 || !_numeric.hasMatch(l.first.text)) continue;
      map[l.first.text] = titleCase(l.skip(1).map((w) => w.text).join(' '));
    }
    return map;
  }

  /// Agrupa palabras en renglones según su coordenada Y.
  static List<List<PdfWord>> _groupLines(List<PdfWord> words) {
    final sorted = [...words]
      ..sort((a, b) {
        final d = a.top.compareTo(b.top);
        return d != 0 ? d : a.left.compareTo(b.left);
      });
    final lines = <List<PdfWord>>[];
    for (final w in sorted) {
      if (w.text.trim().isEmpty) continue;
      if (lines.isNotEmpty && (lines.last.first.top - w.top).abs() < 2.5) {
        lines.last.add(w);
      } else {
        lines.add([w]);
      }
    }
    for (final l in lines) {
      l.sort((a, b) => a.left.compareTo(b.left));
    }
    return lines;
  }

  static int _nearestDay(double x, Map<int, double> centers) {
    var best = 1;
    var bestDist = double.infinity;
    centers.forEach((day, cx) {
      final d = (cx - x).abs();
      if (d < bestDist) {
        bestDist = d;
        best = day;
      }
    });
    return best;
  }

  static double _minGap(List<double> xs) {
    xs.sort();
    var gap = double.infinity;
    for (var i = 1; i < xs.length; i++) {
      final g = xs[i] - xs[i - 1];
      if (g < gap) gap = g;
    }
    return gap.isFinite ? gap : 60;
  }

  /// El reporte termina las clases en :59 (11:00-12:59); se redondea a la hora.
  static DayTime _roundUp(DayTime t) => t.minute == 59 ? DayTime.fromMinutes(t.inMinutes + 1) : t;

  static const _lowerWords = {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'e', 'en', 'por', 'para', 'a', 'o'};

  static const _acronyms = {'ti', 'tic', 'tics', 'wan', 'lan', 'sql', 'erp', 'ia'};

  static String titleCase(String s) {
    final parts = s.toLowerCase().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    return [
      for (var i = 0; i < parts.length; i++)
        if (i > 0 && _lowerWords.contains(parts[i]))
          parts[i]
        else if (_acronyms.contains(parts[i]) || RegExp(r'^[ivx]+$').hasMatch(parts[i]))
          parts[i].toUpperCase()
        else
          parts[i][0].toUpperCase() + parts[i].substring(1),
    ].join(' ');
  }
}

class _Course {
  _Course(this.top);
  final double top;
  String code = '';
  final List<String> parentName = [];
  final List<String> name = [];
  String group = '';
  bool inParent = false;
  bool hasGroupLabel = false;

  String get title {
    final n = SchedulePdfParser.titleCase(name.join(' '));
    if (n.isNotEmpty) return n;
    return SchedulePdfParser.titleCase(parentName.join(' ').replaceAll(']', ''));
  }

  String get groupLabel {
    final parent = SchedulePdfParser.titleCase(parentName.join(' ').replaceAll(']', '').trim());
    final g = group.trim();
    if (parent.isNotEmpty && name.isNotEmpty) {
      return g.isEmpty ? parent : '$parent · Grupo $g';
    }
    return g.isEmpty ? '' : 'Grupo $g';
  }
}
