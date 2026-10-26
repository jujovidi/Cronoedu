import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_view.dart';
import '../state/auth_controller.dart';
import 'rewards_screen.dart';
import 'help_screen.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.profile;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(onTap: () => openRewards(context), child: AvatarView(state.avatar, size: 120)),
                  const SizedBox(height: 8),
                  Text(p.name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  if (state.account case final a?)
                    Text('@${a.nickname} · ${a.email}', style: t.bodySmall, textAlign: TextAlign.center),
                  Text(p.career.isEmpty ? 'Carrera sin definir' : p.career, style: t.bodyMedium),
                  Text('Semestre ${p.semester}', style: t.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Stat(
                        value: '${state.pendingByDueDate.length}',
                        label: 'Pendientes',
                        color: context.colors.pending,
                      ),
                      _Stat(
                        value: '${state.tasks.where((x) => x.isCompleted).length}',
                        label: 'Completadas',
                        color: context.colors.success,
                      ),
                      _Stat(value: '${p.pomodoroCycles + p.flowtimeCycles}', label: 'Ciclos', color: scheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            children: [
              ListTile(
                leading: const Icon(Icons.pets_rounded),
                title: const Text('Mi avatar y ranking'),
                subtitle: const Text('Disfraces, efectos y tu puesto en el podio'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openRewards(context),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Editar información'),
                subtitle: const Text('Nombre, carrera y semestre'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileFormScreen(editing: true))),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_rounded),
                title: const Text('Notificaciones'),
                subtitle: const Text('Recordatorios de tareas y espacios libres para estudiar'),
                value: p.notificationsEnabled,
                onChanged: state.setNotifications,
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_rounded),
                title: const Text('Apariencia'),
                subtitle: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                    ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                  ],
                  selected: {p.themeMode},
                  onSelectionChanged: (s) => state.setThemeMode(s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            children: [
              ListTile(
                leading: const Icon(Icons.help_rounded),
                title: const Text('Ayuda'),
                subtitle: const Text('Tutorial, preguntas frecuentes y manual de usuario'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            children: [
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Cerrar sesión'),
                subtitle: const Text('Tus datos quedan guardados para cuando vuelvas a entrar'),
                onTap: () async {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  await context.read<AuthController>().logout();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: scheme.error),
                title: Text(
                  'Eliminar cuenta',
                  style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Borra tu cuenta, tareas, horario y puntos de este celular'),
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Se borrarán tu perfil, todas tus tareas, tu horario, tus ciclos de estudio, tus bellotas y tu avatar. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final auth = context.read<AuthController>();
    await context.read<AppState>().deleteAccount();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    await auth.deleteAccount();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
