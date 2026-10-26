import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_block.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';

/// Abre el formulario de tarea. Si [task] viene, se edita. No deja crear
/// tareas en fechas anteriores a hoy.
Future<void> showTaskForm(BuildContext context, {DateTime? date, Task? task}) async {
  if (task == null && date != null && AppState.isPastDay(date)) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No puedes agregar tareas en fechas pasadas. Elige hoy o un día futuro.')),
      );
    return;
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TaskForm(initialDate: date, task: task),
  );
}

class TaskForm extends StatefulWidget {
  const TaskForm({super.key, this.initialDate, this.task});

  final DateTime? initialDate;
  final Task? task;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final String _initialSubject;
  TextEditingController? _subjectField;
  late final TextEditingController _topic;
  late final TextEditingController _description;
  DateTime? _date;
  DayTime? _time;
  late DeliveryMode _delivery;
  late TaskComplexity _complexity;
  bool _dateMissing = false;

  bool get _editing => widget.task != null;
  String get _subjectText => _subjectField?.text.trim() ?? _initialSubject;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _initialSubject = t?.subject ?? '';
    _topic = TextEditingController(text: t?.topic ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _date = t?.dueDate ?? widget.initialDate;
    _time = t?.dueTime;
    _delivery = t?.delivery ?? DeliveryMode.virtual;
    _complexity = t?.complexity ?? TaskComplexity.tareita;
  }

  @override
  void dispose() {
    _topic.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    // Al editar una tarea vieja se permite conservar su fecha.
    final first = _date != null && _date!.isBefore(today) ? _date! : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: first,
      lastDate: DateTime(today.year + 3),
      helpText: 'Fecha de entrega',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateMissing = false;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time?.toTimeOfDay() ?? const TimeOfDay(hour: 23, minute: 59),
      helpText: 'Hora de entrega',
    );
    if (picked != null) setState(() => _time = DayTime.fromTimeOfDay(picked));
  }

  String? get _pastError {
    final d = _date;
    if (d == null || (_editing && DateUtils.isSameDay(d, widget.task!.dueDate))) return null;
    if (AppState.isPastDay(d)) return 'La fecha no puede ser anterior a hoy';
    final t = _time;
    if (t != null && DateUtils.isSameDay(d, DateTime.now())) {
      final now = TimeOfDay.now();
      if (t.inMinutes <= now.hour * 60 + now.minute) return 'Esa hora de hoy ya pasó';
    }
    return null;
  }

  void _save() {
    final formOk = _formKey.currentState!.validate();
    setState(() => _dateMissing = _date == null);
    if (!formOk || _date == null || _pastError != null) return;
    final state = context.read<AppState>();
    if (_editing) {
      final t = widget.task!
        ..subject = _subjectText
        ..topic = _topic.text.trim()
        ..dueDate = DateUtils.dateOnly(_date!)
        ..dueTime = _time
        ..delivery = _delivery
        ..complexity = _complexity
        ..description = _description.text.trim();
      state.updateTask(t);
    } else {
      state.addTask(
        subject: _subjectText,
        topic: _topic.text,
        dueDate: _date!,
        dueTime: _time,
        delivery: _delivery,
        complexity: _complexity,
        description: _description.text,
      );
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_editing ? 'Tarea actualizada' : 'Tarea guardada como pendiente')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final subjects = context.read<AppState>().knownSubjects;
    final pending = widget.task?.isCompleted != true;
    final dateColor = pending ? colors.pending : colors.success;
    final dateError = _dateMissing ? 'Elige el día de entrega (obligatorio)' : _pastError;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _editing ? 'Editar tarea' : 'Nueva tarea',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _initialSubject),
                optionsBuilder: (v) => v.text.isEmpty
                    ? const Iterable.empty()
                    : subjects.where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  _subjectField = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focus,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Materia *',
                      prefixIcon: Icon(Icons.menu_book_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe la materia' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _topic,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tema *',
                  hintText: 'Ej: Taller 3, ensayo, parcial',
                  prefixIcon: Icon(Icons.topic_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el tema' : null,
              ),
              const SizedBox(height: 12),
              // Día de entrega (obligatorio) + hora (opcional)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Día de entrega *',
                          prefixIcon: Icon(Icons.event_rounded, color: dateColor),
                          errorText: dateError,
                          errorMaxLines: 2,
                        ),
                        child: Text(
                          _date == null ? 'Elegir día' : capitalize(shortDate(_date!)),
                          style: TextStyle(
                            color: _date == null ? scheme.onSurfaceVariant : dateColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Hora',
                          prefixIcon: const Icon(Icons.schedule_rounded),
                          suffixIcon: _time == null
                              ? null
                              : IconButton(
                                  tooltip: 'Quitar hora',
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => setState(() => _time = null),
                                ),
                        ),
                        child: Text(
                          _time?.format() ?? 'Opcional',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _time == null ? scheme.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Entrega', style: t.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<DeliveryMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: DeliveryMode.virtual,
                    label: Text('Virtual'),
                    icon: Icon(Icons.cloud_upload_rounded),
                  ),
                  ButtonSegment(
                    value: DeliveryMode.fisico,
                    label: Text('En físico'),
                    icon: Icon(Icons.description_rounded),
                  ),
                ],
                selected: {_delivery},
                onSelectionChanged: (s) => setState(() => _delivery = s.first),
              ),
              if (_delivery == DeliveryMode.fisico)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Se mostrará sobre tu clase de esta materia ese día.', style: t.bodySmall),
                ),
              const SizedBox(height: 16),
              Text('Complejidad', style: t.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<TaskComplexity>(
                showSelectedIcon: false,
                segments: [
                  for (final c in TaskComplexity.values)
                    ButtonSegment(
                      value: c,
                      label: Text(c.label, textAlign: TextAlign.center),
                    ),
                ],
                selected: {_complexity},
                onSelectionChanged: (s) => setState(() => _complexity = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                'Tiempo estimado: ~${_complexity.estimatedHours.toStringAsFixed(_complexity.estimatedHours % 1 == 0 ? 0 : 1)} h · '
                'Te recordaremos empezar ${_complexity.daysAhead} días antes.',
                style: t.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)', alignLabelWithHint: true),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_editing ? 'GUARDAR CAMBIOS' : 'GUARDAR TAREA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
