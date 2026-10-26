import 'schedule_block.dart';

/// Complejidad de una tarea. Define un nivel interno de dificultad que el
/// planificador usa para estimar el tiempo de trabajo y priorizar.
enum TaskComplexity {
  tareita('Tareita', 1, 1.5),
  proyecto('Proyecto', 2, 6),
  proyectoFinal('Proyecto final', 3, 15);

  const TaskComplexity(this.label, this.level, this.estimatedHours);

  final String label;

  /// Nivel interno de dificultad (1 = baja, 3 = alta).
  final int level;

  /// Horas de trabajo estimadas para completar una tarea de este tipo.
  final double estimatedHours;

  /// Días de anticipación con los que conviene empezar a trabajarla.
  int get daysAhead => switch (this) {
    TaskComplexity.tareita => 2,
    TaskComplexity.proyecto => 7,
    TaskComplexity.proyectoFinal => 21,
  };
}

enum TaskStatus { pendiente, completada }

/// Cómo se entrega: virtual (por plataforma, correo...) o en físico en clase.
enum DeliveryMode {
  virtual('Virtual'),
  fisico('En físico');

  const DeliveryMode(this.label);
  final String label;
}

class Task {
  Task({
    required this.id,
    required this.subject,
    required this.dueDate,
    required this.complexity,
    this.topic = '',
    this.dueTime,
    this.delivery = DeliveryMode.virtual,
    this.description = '',
    this.status = TaskStatus.pendiente,
    this.completedAt,
  });

  final String id;
  String subject;
  DateTime dueDate;
  TaskComplexity complexity;

  /// Tema o nombre corto de la tarea (ej: "Taller 3").
  String topic;

  /// Hora de entrega opcional.
  DayTime? dueTime;
  DeliveryMode delivery;
  String description;
  TaskStatus status;
  DateTime? completedAt;

  bool get isPending => status == TaskStatus.pendiente;
  bool get isCompleted => status == TaskStatus.completada;

  /// Título para mostrar: "Materia · Tema".
  String get title => topic.isEmpty ? subject : '$subject · $topic';

  /// Fecha y hora exacta de entrega (fin del día si no tiene hora).
  DateTime get dueDateTime {
    final d = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final t = dueTime;
    return t == null ? d.add(const Duration(hours: 23, minutes: 59)) : d.add(Duration(minutes: t.inMinutes));
  }

  /// Días que faltan para la entrega (negativo si ya pasó).
  int daysLeft([DateTime? now]) {
    final today = _dateOnly(now ?? DateTime.now());
    return _dateOnly(dueDate).difference(today).inDays;
  }

  /// Puntaje de prioridad: más alto = más urgente. Combina la cercanía de la
  /// entrega con la complejidad de la tarea.
  double priority([DateTime? now]) {
    final days = daysLeft(now).clamp(-30, 365);
    final urgency = days <= 0 ? 10.0 : complexity.daysAhead / days;
    return urgency * complexity.level;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'dueDate': dueDate.toIso8601String(),
    'complexity': complexity.name,
    'topic': topic,
    'dueTime': dueTime?.inMinutes,
    'delivery': delivery.name,
    'description': description,
    'status': status.name,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    subject: json['subject'] as String,
    dueDate: DateTime.parse(json['dueDate'] as String),
    complexity: TaskComplexity.values.byName(json['complexity'] as String),
    topic: (json['topic'] as String?) ?? '',
    dueTime: json['dueTime'] == null ? null : DayTime.fromMinutes(json['dueTime'] as int),
    delivery: DeliveryMode.values.byName((json['delivery'] as String?) ?? 'virtual'),
    description: (json['description'] as String?) ?? '',
    status: TaskStatus.values.byName(json['status'] as String),
    completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
