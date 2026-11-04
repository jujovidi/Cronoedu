import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Campo de materia con las materias del calendario y de las tareas. Al
/// tocarlo muestra todas; al escribir, las filtra. También acepta una nueva.
class SubjectAutocomplete extends StatelessWidget {
  const SubjectAutocomplete({super.key, required this.initial, required this.onField, this.label = 'Materia *'});

  final String initial;
  final String label;

  /// Entrega el controlador del texto para leerlo al guardar.
  final ValueChanged<TextEditingController> onField;

  @override
  Widget build(BuildContext context) {
    final subjects = context.read<AppState>().knownSubjects;
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initial),
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        return q.isEmpty ? subjects : subjects.where((s) => s.toLowerCase().contains(q));
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) {
        onField(controller);
        return TextFormField(
          controller: controller,
          focusNode: focus,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.menu_book_rounded)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Elige o escribe la materia' : null,
        );
      },
    );
  }
}

/// Pregunta la materia y el tema de una sesión de estudio antes de agendarla.
/// Devuelve null si el usuario cancela.
Future<({String subject, String topic})?> askStudyTopic(
  BuildContext context, {
  String subject = '',
  String topic = '',
}) {
  return showDialog<({String subject, String topic})>(
    context: context,
    builder: (_) => _StudyTopicDialog(subject: subject, topic: topic),
  );
}

class _StudyTopicDialog extends StatefulWidget {
  const _StudyTopicDialog({required this.subject, required this.topic});
  final String subject;
  final String topic;

  @override
  State<_StudyTopicDialog> createState() => _StudyTopicDialogState();
}

class _StudyTopicDialogState extends State<_StudyTopicDialog> {
  final _form = GlobalKey<FormState>();
  TextEditingController? _subject;
  late final _topic = TextEditingController(text: widget.topic);

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (subject: _subject!.text.trim(), topic: _topic.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('¿Qué vas a estudiar?'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Con la materia y el tema armamos tus recomendaciones de estudio.'),
          const SizedBox(height: 12),
          SubjectAutocomplete(initial: widget.subject, onField: (c) => _subject = c),
          const SizedBox(height: 12),
          TextFormField(
            controller: _topic,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tema (opcional)',
              hintText: 'Ej: Dinámica de sistemas',
              prefixIcon: Icon(Icons.topic_rounded),
            ),
            onFieldSubmitted: (_) => _save(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(onPressed: _save, child: const Text('Agendar')),
    ],
  );
}
