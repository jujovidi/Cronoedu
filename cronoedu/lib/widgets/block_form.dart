import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_block.dart';
import '../state/app_state.dart';
import 'study_topic_fields.dart';
import 'task_tile.dart' show confirmDelete;

/// Formulario para agregar bloques semanales (clase, ocio, trabajo,
/// extracurricular) o editar uno existente.
Future<void> showBlockForm(
  BuildContext context, {
  BlockType type = BlockType.ocio,
  ScheduleBlock? block,
  int? weekday,
  DayTime? start,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlockForm(type: block?.type ?? type, block: block, initialWeekday: weekday, initialStart: start),
  );
}

class BlockForm extends StatefulWidget {
  const BlockForm({super.key, required this.type, this.block, this.initialWeekday, this.initialStart});
  final BlockType type;
  final ScheduleBlock? block;
  final int? initialWeekday;
  final DayTime? initialStart;

  @override
  State<BlockForm> createState() => _BlockFormState();
}

class _BlockFormState extends State<BlockForm> {
  final _formKey = GlobalKey<FormState>();
  late BlockType _type;
  late final TextEditingController _title;
  late final TextEditingController _room;
  late final TextEditingController _topic;
  TextEditingController? _subject;
  late Set<int> _days;
  late DayTime _start;
  late DayTime _end;

  bool get _editing => widget.block != null;

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    _type = widget.type;
    _title = TextEditingController(text: b?.title ?? '');
    _room = TextEditingController(text: b?.room ?? '');
    _topic = TextEditingController(text: b?.topic ?? '');
    _days = b != null ? {b.weekday} : {if (widget.initialWeekday != null) widget.initialWeekday!};
    _start = b?.start ?? widget.initialStart ?? const DayTime(14, 0);
    _end = b?.end ?? DayTime.fromMinutes((_start.inMinutes + 120).clamp(0, 23 * 60 + 59));
  }

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _topic.dispose();
    super.dispose();
  }

  String get _hint => switch (_type) {
    BlockType.clase => 'Ej: Cálculo diferencial',
    BlockType.ocio => 'Ej: Gimnasio, series, salir con amigos',
    BlockType.trabajo => 'Ej: Turno en la tienda',
    BlockType.extracurricular => 'Ej: Selección de fútbol, curso de inglés',
    BlockType.estudio => 'Ej: Repaso semanal de cálculo',
  };

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end).toTimeOfDay(),
      helpText: start ? 'Hora de inicio' : 'Hora de fin',
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = DayTime.fromTimeOfDay(picked);
      } else {
        _end = DayTime.fromTimeOfDay(picked);
      }
    });
  }

  /// Aviso cuando la hora de inicio y la de fin no forman un rango válido.
  String? get _timeError {
    if (_start == _end) return 'La hora de inicio y la de fin no pueden ser iguales.';
    if (_end.inMinutes < _start.inMinutes) return 'La hora de fin debe ser después de la de inicio.';
    return null;
  }

  String get _durationLabel {
    final m = _end.inMinutes - _start.inMinutes;
    final h = m ~/ 60;
    final r = m % 60;
    return 'Duración: ${h > 0 ? '$h h ' : ''}${r > 0 ? '$r min' : ''}'.trim();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _timeError != null) return;
    if (_days.isEmpty && !(widget.block?.isOneOff ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Elige al menos un día')));
      return;
    }
    final state = context.read<AppState>();
    final conflicts = [for (final d in _days) ...state.conflictsWith(d, _start, _end, ignoreId: widget.block?.id)];
    if (conflicts.isNotEmpty) {
      final names = conflicts.map((c) => '${weekdayShort[c.weekday - 1]} ${c.title}').toSet().join(', ');
      final ok = await confirmDelete(
        context,
        'Este horario se cruza con: $names. ¿Guardar de todos modos?',
        confirm: 'Guardar',
      );
      if (!ok || !mounted) return;
    }

    // Las sesiones de estudio se nombran por su materia; las demás no la usan.
    final study = _type == BlockType.estudio;
    final subject = study ? (_subject?.text.trim() ?? '') : '';
    final topic = study ? _topic.text.trim() : '';
    final title = study ? 'Estudio: $subject' : _title.text.trim();

    if (_editing) {
      final b = widget.block!
        ..type = _type
        ..title = title
        ..subject = subject
        ..topic = topic
        ..room = _room.text.trim()
        ..weekday = widget.block!.isOneOff ? widget.block!.weekday : _days.first
        ..start = _start
        ..end = _end;
      state.updateBlock(b);
      final extra = b.isOneOff ? const <int>[] : _days.skip(1);
      if (extra.isNotEmpty) {
        state.addBlocks(
          type: _type,
          title: b.title,
          weekdays: extra,
          start: _start,
          end: _end,
          room: b.room,
          subject: subject,
          topic: topic,
        );
      }
    } else {
      state.addBlocks(
        type: _type,
        title: title,
        weekdays: _days.toList()..sort(),
        start: _start,
        end: _end,
        room: _room.text,
        subject: subject,
        topic: topic,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
                _editing ? 'Editar actividad' : 'Nueva actividad semanal',
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('Estas horas se respetan: la app no te sugerirá estudiar en ellas.', style: t.bodySmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final bt in BlockType.values)
                    ChoiceChip(
                      avatar: Icon(bt.icon, size: 18),
                      label: Text(bt.label),
                      selected: _type == bt,
                      onSelected: (_) => setState(() => _type = bt),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_type == BlockType.estudio) ...[
                SubjectAutocomplete(initial: widget.block?.studySubject ?? '', onField: (c) => _subject = c),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _topic,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tema (opcional)',
                    hintText: 'Ej: Dinámica de sistemas',
                    prefixIcon: Icon(Icons.topic_rounded),
                  ),
                ),
              ] else
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Nombre', hintText: _hint, prefixIcon: Icon(_type.icon)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
                ),
              if (_type == BlockType.clase) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _room,
                  decoration: const InputDecoration(
                    labelText: 'Salón (opcional)',
                    prefixIcon: Icon(Icons.room_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.block?.isOneOff ?? false)
                Text(
                  'Sesión de un solo día: ${weekdayNames[widget.block!.date!.weekday - 1]} '
                  '${widget.block!.date!.day}/${widget.block!.date!.month}',
                  style: t.labelLarge,
                )
              else ...[
                Text('Días', style: t.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(weekdayShort[d - 1]),
                        selected: _days.contains(d),
                        onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(label: 'Inicio', value: _start, onTap: () => _pickTime(true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(label: 'Fin', value: _end, onTap: () => _pickTime(false)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _timeError == null
                    ? Text(_durationLabel, key: const ValueKey('ok'), style: t.bodySmall)
                    : Container(
                        key: const ValueKey('error'),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _timeError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _timeError == null ? _save : null,
                icon: const Icon(Icons.check_rounded),
                label: const Text('GUARDAR'),
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () {
                    context.read<AppState>().deleteBlock(widget.block!);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar actividad'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onTap});
  final String label;
  final DayTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.schedule_rounded)),
      child: Text(value.format(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    ),
  );
}
