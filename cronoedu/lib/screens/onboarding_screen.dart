import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/mascot.dart';

/// Primera vez que se abre la app: crear el perfil local.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => const ProfileFormScreen(editing: false);
}

/// Formulario de nombre, carrera y semestre (registro y "Editar información").
class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key, required this.editing});
  final bool editing;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _career;
  late int _semester;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _name = TextEditingController(text: p.name);
    _career = TextEditingController(text: p.career);
    _semester = p.semester;
  }

  @override
  void dispose() {
    _name.dispose();
    _career.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AppState>().updateProfile(name: _name.text.trim(), career: _career.text.trim(), semester: _semester);
    if (widget.editing) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Información actualizada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: widget.editing ? AppBar(title: const Text('Editar información')) : null,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!widget.editing) ...[
                const SizedBox(height: 24),
                const Mascot(MascotPose.escritorio, size: 170),
                const SizedBox(height: 16),
                Text(
                  '¡Bienvenido a CronoEdu!',
                  textAlign: TextAlign.center,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Organiza tus tareas, respeta tu horario y estudia con técnicas que funcionan. '
                  'Tus datos se guardan solo en este celular.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 28),
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _career,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Carrera', prefixIcon: Icon(Icons.school_rounded)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _semester,
                decoration: const InputDecoration(labelText: 'Semestre', prefixIcon: Icon(Icons.stairs_rounded)),
                items: [for (var s = 1; s <= 12; s++) DropdownMenuItem(value: s, child: Text('Semestre $s'))],
                onChanged: (v) => setState(() => _semester = v ?? 1),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: Text(widget.editing ? 'GUARDAR' : 'EMPEZAR')),
            ],
          ),
        ),
      ),
    );
  }
}
