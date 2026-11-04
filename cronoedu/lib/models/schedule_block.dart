import 'package:flutter/material.dart';

/// Tipo de bloque semanal del horario.
enum BlockType {
  clase('Clase', Icons.school_rounded),
  ocio('Ocio', Icons.sports_esports_rounded),
  trabajo('Trabajo', Icons.work_rounded),
  extracurricular('Extracurricular', Icons.emoji_events_rounded),
  estudio('Estudio autónomo', Icons.auto_stories_rounded);

  const BlockType(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Hora del día en minutos desde la medianoche, para guardar y comparar fácil.
class DayTime implements Comparable<DayTime> {
  const DayTime(this.hour, this.minute);
  const DayTime.fromMinutes(int m) : hour = m ~/ 60, minute = m % 60;

  final int hour;
  final int minute;

  int get inMinutes => hour * 60 + minute;

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);
  static DayTime fromTimeOfDay(TimeOfDay t) => DayTime(t.hour, t.minute);

  /// Acepta "07:00" o "7:00".
  static DayTime parse(String s) {
    final parts = s.trim().split(':');
    return DayTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  String format() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  int compareTo(DayTime other) => inMinutes.compareTo(other.inMinutes);

  @override
  bool operator ==(Object other) => other is DayTime && other.inMinutes == inMinutes;

  @override
  int get hashCode => inMinutes;

  @override
  String toString() => format();
}

/// Un bloque que se repite cada semana (clase, ocio, trabajo o extracurricular).
class ScheduleBlock {
  ScheduleBlock({
    required this.id,
    required this.type,
    required this.title,
    required this.weekday,
    required this.start,
    required this.end,
    this.room = '',
    this.teacher = '',
    this.group = '',
    this.subject = '',
    this.topic = '',
    this.date,
  });

  final String id;
  BlockType type;
  String title;

  /// 1 = lunes ... 7 = domingo (igual que DateTime.weekday).
  int weekday;
  DayTime start;
  DayTime end;
  String room;
  String teacher;
  String group;

  /// Materia y tema de una sesión de estudio autónomo (vacíos en los demás tipos).
  String subject;
  String topic;

  /// Materia con la que se buscan recomendaciones. Las sesiones guardadas
  /// antes de existir [subject] usan el título sin el prefijo "Estudio: ".
  String get studySubject {
    if (subject.isNotEmpty) return subject;
    final t = title.trim();
    return t.startsWith('Estudio: ') ? t.substring(9) : t;
  }

  /// "Modelación · Dinámica de sistemas" o solo la materia.
  String get studyLabel => topic.isEmpty ? studySubject : '$studySubject · $topic';

  /// Si tiene fecha, el bloque es de un solo día (ej: una sesión de estudio
  /// agendada). Si es null, se repite cada semana.
  DateTime? date;

  bool get isOneOff => date != null;

  /// ¿Este bloque ocupa tiempo el día [day]?
  bool appliesTo(DateTime day) {
    final d = date;
    if (d == null) return weekday == day.weekday;
    return d.year == day.year && d.month == day.month && d.day == day.day;
  }

  int get durationMinutes => end.inMinutes - start.inMinutes;

  bool overlaps(DayTime s, DayTime e) => start.inMinutes < e.inMinutes && s.inMinutes < end.inMinutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'weekday': weekday,
    'start': start.inMinutes,
    'end': end.inMinutes,
    'room': room,
    'teacher': teacher,
    'group': group,
    'subject': subject,
    'topic': topic,
    'date': date?.toIso8601String(),
  };

  factory ScheduleBlock.fromJson(Map<String, dynamic> json) => ScheduleBlock(
    id: json['id'] as String,
    type: BlockType.values.byName(json['type'] as String),
    title: json['title'] as String,
    weekday: json['weekday'] as int,
    start: DayTime.fromMinutes(json['start'] as int),
    end: DayTime.fromMinutes(json['end'] as int),
    room: (json['room'] as String?) ?? '',
    teacher: (json['teacher'] as String?) ?? '',
    group: (json['group'] as String?) ?? '',
    subject: (json['subject'] as String?) ?? '',
    topic: (json['topic'] as String?) ?? '',
    date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
  );
}

/// Una sesión de estudio autónomo en una fecha concreta. Las semanales se
/// repiten, así que cada semana es una ocurrencia distinta del mismo bloque.
class StudySession {
  const StudySession(this.block, this.day);
  final ScheduleBlock block;
  final DateTime day;

  DateTime get start => DateTime(day.year, day.month, day.day, block.start.hour, block.start.minute);
  DateTime get end => DateTime(day.year, day.month, day.day, block.end.hour, block.end.minute);
}

const weekdayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

const weekdayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
