import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../services/rewards.dart';
import '../state/app_state.dart';
import '../state/study_timer.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_view.dart';
import '../widgets/mascot.dart';
import '../widgets/reward_feedback.dart';
import '../widgets/timer_ring.dart';
import 'rewards_screen.dart';
import 'shell.dart';

const _focusPhrases = [
  'Un paso a la vez. ¡Tú puedes!',
  'Celular lejos, mente cerca.',
  'Cada minuto cuenta para tu meta.',
  'Concéntrate en una sola cosa.',
  'Si te distraes, vuelve sin culpa.',
  'Respira hondo y sigue.',
];

const _breakPhrases = [
  'Estírate y toma agua.',
  'Mira lejos de la pantalla un momento.',
  'Camina un poco, tu cerebro lo agradece.',
  'Descansar también es avanzar.',
];

/// Técnicas de estudio: Pomodoro y Flowtime con su temporizador de 4 estados.
class TechniquesScreen extends StatelessWidget {
  const TechniquesScreen({super.key});

  Future<void> _select(BuildContext context, Technique t) async {
    final timer = context.read<StudyTimer>();
    if (t == timer.technique) return;
    if (!timer.isIdle && timer.phase != TimerPhase.logro) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: const Text('Tienes una sesión en curso. ¿Cambiar de técnica y abandonarla?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cambiar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    timer.selectTechnique(t);
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<StudyTimer>();
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Técnicas de estudio'), actions: const [ProfileButton()]),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TechniqueCard(
                      title: 'Pomodoro',
                      subtitle: '25 min + descanso',
                      icon: Icons.timer_rounded,
                      selected: timer.technique == Technique.pomodoro,
                      onTap: () => _select(context, Technique.pomodoro),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TechniqueCard(
                      title: 'Flowtime',
                      subtitle: 'A tu ritmo',
                      icon: Icons.waves_rounded,
                      selected: timer.technique == Technique.flowtime,
                      onTap: () => _select(context, Technique.flowtime),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatsStrip(state: state, timer: timer),
              const SizedBox(height: 8),
              if (state.activeTask != null || state.activeSession != null) _ActiveTask(state: state),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(anim), child: child),
                ),
                child: timer.phase == TimerPhase.logro
                    ? _Achievement(key: const ValueKey('logro'), timer: timer)
                    : _TimerView(
                        key: ValueKey(
                          '${timer.technique}-${timer.phase == TimerPhase.pausa ? timer.pausedFromFocus : timer.phase}',
                        ),
                      ),
              ),
            ],
          ),
          if (timer.awaitingPresence) _PresenceCheck(timer: timer),
        ],
      ),
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  const _TechniqueCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : scheme.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selected ? null : scheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: selected
            ? [BoxShadow(color: scheme.primary.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 6))]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: selected ? 0 : -.05,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(icon, color: selected ? Colors.white : scheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(subtitle, style: TextStyle(color: fg.withValues(alpha: .8), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Minutos de hoy, ciclos y ayuda, con números animados.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.state, required this.timer});
  final AppState state;
  final StudyTimer timer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = state.profile;
    final total = timer.technique == Technique.pomodoro ? p.pomodoroCycles : p.flowtimeCycles;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatPill(
                icon: Icons.local_fire_department_rounded,
                color: c.creative,
                value: state.studyMinutesToday,
                suffix: ' min hoy',
              ),
              _StatPill(
                icon: Icons.emoji_events_rounded,
                color: c.success,
                value: timer.sessionCycles,
                suffix: ' ciclos · $total en total',
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: '¿Cómo funciona?',
          onPressed: () => _showHelp(context, timer.technique),
          icon: const Icon(Icons.question_mark_rounded),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.color, required this.value, required this.suffix});
  final IconData icon;
  final Color color;
  final int value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 700),
            builder: (_, v, _) => Text(
              '$v$suffix',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTask extends StatelessWidget {
  const _ActiveTask({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final task = state.activeTask;
    final session = state.activeSession;
    return Card(
      child: ListTile(
        title: Text(
          task != null ? 'TAREA ACTIVA' : 'SESIÓN DE ESTUDIO',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        subtitle: Text(
          task?.title ?? session!.studyLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: IconButton(
          tooltip: 'Quitar tarea activa',
          icon: const Icon(Icons.close_rounded),
          onPressed: state.clearActiveTask,
        ),
      ),
    );
  }
}

/// Animación continua para "respirar": el anillo late y el mapache flota.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.active, required this.child, this.amplitude = .035});
  final bool active;
  final Widget child;
  final double amplitude;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Breathing old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) =>
        Transform.scale(scale: 1 + widget.amplitude * Curves.easeInOut.transform(_c.value), child: child),
    child: widget.child,
  );
}

/// La mascota dentro del anillo. Pomodoro: se come un tomate durante los 25
/// minutos. Flowtime: estudia con la batería llena y en el descanso duerme.
class _TimerMascot extends StatelessWidget {
  const _TimerMascot({required this.timer});
  final StudyTimer timer;

  @override
  Widget build(BuildContext context) {
    final phase = timer.phase;
    final tick = timer.elapsed.inSeconds;
    if (timer.technique == Technique.pomodoro) {
      if (phase == TimerPhase.descanso) return const Mascot(MascotPose.descanso, size: 80);
      if (!(timer.isIdle || timer.inFocus)) return const SizedBox.shrink();
      return TomatoMascot(
        progress: timer.isIdle ? 0 : timer.progress,
        chewing: phase == TimerPhase.enfoque && tick.isOdd,
        size: 92,
      );
    }
    if (phase == TimerPhase.descanso) return SleepingMascot(frame: tick ~/ 2, size: 84);
    if (!(timer.isIdle || timer.inFocus)) return const SizedBox.shrink();
    return _Bobbing(active: phase == TimerPhase.enfoque, child: const StudyingMascot(size: 92));
  }
}

/// Muestra el temporizador según el estado: enfoque, pausa, descanso.
class _TimerView extends StatelessWidget {
  const _TimerView({super.key});

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<StudyTimer>();
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final isFlow = timer.technique == Technique.flowtime;
    final phase = timer.phase;

    final (Color color, String label, List<Color>? gradient) = switch (phase) {
      TimerPhase.enfoque => (scheme.primary, '¡ENFOQUE!', [scheme.primary, c.focus, scheme.primary]),
      TimerPhase.pausa => (c.paused, 'PAUSADO', null),
      TimerPhase.descanso => (c.success, 'DESCANSO', null),
      _ => (scheme.primary, isFlow ? 'FLOWTIME' : 'POMODORO', null),
    };
    final timeColor = phase == TimerPhase.pausa
        ? c.paused
        : (phase == TimerPhase.descanso ? c.success : scheme.tertiary);
    final phrases = phase == TimerPhase.descanso ? _breakPhrases : _focusPhrases;
    final phrase = phrases[(timer.elapsed.inSeconds ~/ 20) % phrases.length];
    final running = timer.isRunning;

    return Column(
      children: [
        Text(
          formatDuration(timer.display),
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: timeColor,
            letterSpacing: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            timer.isIdle
                ? (isFlow ? 'Estudia a tu ritmo y para cuando pierdas el foco.' : '25 minutos de foco total. ¿Listo?')
                : phrase,
            key: ValueKey(timer.isIdle ? 'idle' : phrase),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 14),
        _Breathing(
          active: phase == TimerPhase.enfoque || phase == TimerPhase.descanso,
          amplitude: .025,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: running ? [BoxShadow(color: color.withValues(alpha: .16), blurRadius: 30)] : null,
            ),
            child: TimerRing(
              progress: timer.progress,
              color: color,
              gradient: gradient,
              dashed: phase == TimerPhase.pausa,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TimerMascot(timer: timer),
                  Text(
                    label,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: scheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isFlow && timer.inFocus && !timer.focusIsValid) ...[
          const SizedBox(height: 14),
          _MinFocusProgress(timer: timer),
        ],
        const SizedBox(height: 20),
        ..._buttons(context, timer),
      ],
    );
  }

  Future<void> _finishFlow(BuildContext context, StudyTimer timer) async {
    if (timer.finishFocus()) return;
    final left = StudyTimer.flowtimeMinFocus - timer.elapsed;
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Mascot(MascotPose.enfoque, size: 60),
        title: const Text('Aún no cuenta como sesión'),
        content: Text(
          'En Flowtime una sesión válida dura mínimo 10 minutos. '
          'Te faltan ${formatDuration(left)}. Si terminas ahora no se suma el ciclo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terminar sin contar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir estudiando')),
        ],
      ),
    );
    if (stop == true) timer.reset();
  }

  List<Widget> _buttons(BuildContext context, StudyTimer timer) {
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final isFlow = timer.technique == Technique.flowtime;
    Widget btn(String text, Color bg, VoidCallback onTap, {Color fg = Colors.white, IconData? icon}) => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg),
        onPressed: onTap,
        icon: Icon(icon ?? Icons.circle, size: icon == null ? 0 : 20),
        label: Text(text),
      ),
    );
    const gap = SizedBox(height: 10);

    return switch (timer.phase) {
      TimerPhase.listo => [btn('EMPEZAR', scheme.primary, timer.start, icon: Icons.play_arrow_rounded)],
      TimerPhase.enfoque => [
        Row(
          children: [
            Expanded(
              child: btn('PAUSAR', scheme.tertiary, timer.pause, fg: scheme.onTertiary, icon: Icons.pause_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(child: btn('ABANDONAR', c.creative, timer.reset, icon: Icons.close_rounded)),
          ],
        ),
        if (isFlow) ...[
          gap,
          btn('TERMINAR ENFOQUE', c.success, () => _finishFlow(context, timer), icon: Icons.flag_rounded),
        ],
      ],
      TimerPhase.pausa => [
        btn('CONTINUAR', scheme.primary, timer.resume, icon: Icons.play_arrow_rounded),
        gap,
        btn('ABANDONAR', c.creative, timer.reset, icon: Icons.close_rounded),
        if (isFlow && timer.pausedFromFocus) ...[
          gap,
          btn('TERMINAR ENFOQUE', c.success, () => _finishFlow(context, timer), icon: Icons.flag_rounded),
        ],
      ],
      TimerPhase.descanso => [
        btn(
          'OMITIR DESCANSO',
          Theme.of(context).brightness == Brightness.dark ? scheme.surfaceContainerHighest : const Color(0xFF2C3539),
          timer.skipBreak,
          icon: Icons.skip_next_rounded,
        ),
        gap,
        btn('PAUSAR', scheme.tertiary, timer.pause, fg: scheme.onTertiary, icon: Icons.pause_rounded),
      ],
      TimerPhase.logro => const [],
    };
  }
}

/// Mapache que sube y baja suavemente mientras estudias.
class _Bobbing extends StatefulWidget {
  const _Bobbing({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<_Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<_Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Bobbing old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, -5 * Curves.easeInOut.transform(_c.value)),
      child: Transform.rotate(angle: (_c.value - .5) * .08, child: child),
    ),
    child: widget.child,
  );
}

/// Flowtime: barra hasta los 10 minutos mínimos.
class _MinFocusProgress extends StatelessWidget {
  const _MinFocusProgress({required this.timer});
  final StudyTimer timer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final min = StudyTimer.flowtimeMinFocus;
    final value = (timer.elapsed.inMilliseconds / min.inMilliseconds).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            color: c.creative,
            backgroundColor: c.creative.withValues(alpha: .15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Faltan ${formatDuration(min - timer.elapsed)} para que la sesión sea válida (mínimo 10 min)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// "¿Sigues ahí?" de Flowtime: si no responde en 1 minuto, termina el enfoque.
class _PresenceCheck extends StatelessWidget {
  const _PresenceCheck({required this.timer});
  final StudyTimer timer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final left = timer.presenceTimeLeft;
    final fraction = left.inMilliseconds / StudyTimer.presenceTimeout.inMilliseconds;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: .45),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Breathing(active: true, amplitude: .08, child: Mascot(MascotPose.enfoque, size: 90)),
                    const SizedBox(height: 8),
                    Text(
                      '¿Sigues ahí?',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Llevas ${timer.elapsed.inHours} h ${timer.elapsed.inMinutes.remainder(60)} min de enfoque. '
                      'Si no respondes, cerramos la sesión y empieza tu descanso.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(value: fraction, strokeWidth: 6, color: c.creative),
                          Text('${left.inSeconds}s', style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: timer.confirmPresence, child: const Text('¡SÍ, SIGO AQUÍ!')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Achievement extends StatelessWidget {
  const _Achievement({super.key, required this.timer});
  final StudyTimer timer;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final task = state.activeTask;
    final scheme = Theme.of(context).colorScheme;
    final c = context.colors;
    final minutes = timer.lastFocus.inMinutes;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('¡BIEN HECHO!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                Text(
                  minutes < 1 ? '${timer.lastFocus.inSeconds} s de enfoque' : '$minutes min de enfoque',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < 8; i++) _Sparkle(index: i, color: i.isEven ? c.creative : scheme.primary),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: .3, end: 1),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                        child: AvatarView(state.avatar, size: 150),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (state.lastReward case final r? when !r.isEmpty) ...[
                  RewardBadge(r),
                  if (r.newLevel != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '¡Subiste a nivel ${r.newLevel}! Mira lo nuevo en tu avatar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900, color: scheme.primary),
                    ),
                    TextButton.icon(
                      onPressed: () => openRewards(context),
                      icon: const Icon(Icons.pets_rounded),
                      label: const Text('Ir a Recompensas'),
                    ),
                  ],
                  const SizedBox(height: 8),
                ] else if (timer.lastFocus.inMinutes < Rewards.minCycleFocusMinutes) ...[
                  Text(
                    'Los ciclos dan bellotas desde ${Rewards.minCycleFocusMinutes} min de enfoque.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Ciclo cerrado. Llevas ${timer.sessionCycles} '
                  '${timer.sessionCycles == 1 ? 'ciclo' : 'ciclos'} en esta sesión.',
                ),
                if (timer.endedByAbsence) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Como no respondiste "¿Sigues ahí?", cerramos el enfoque a las '
                    '${timer.lastFocus.inHours} h.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: scheme.tertiary),
            onPressed: timer.start,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('EMPEZAR SIGUIENTE'),
          ),
        ),
        if (task != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final reward = state.setTaskStatus(task, TaskStatus.completada);
                timer.reset();
                showRewardSnack(context, reward, message: '¡${task.subject} completada!');
              },
              icon: Icon(Icons.check_circle_rounded, color: c.success),
              label: const Text('Terminé la tarea'),
            ),
          ),
        ],
        TextButton(onPressed: timer.reset, child: const Text('Terminar sesión')),
      ],
    );
  }
}

/// Estrellita que sale disparada alrededor del mapache en la pantalla de logro.
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.index, required this.color});
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final angle = index / 8 * 2 * math.pi;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Transform.translate(
        offset: Offset(math.cos(angle) * 78 * v, math.sin(angle) * 70 * v),
        child: Opacity(
          opacity: (1.2 - v).clamp(.35, 1),
          child: Icon(Icons.star_rounded, size: 14 + 6 * v, color: color),
        ),
      ),
    );
  }
}

void _showHelp(BuildContext context, Technique t) {
  final (title, body) = switch (t) {
    Technique.pomodoro => (
      '¿Cómo funciona Pomodoro?',
      '1. Elige una tarea y concéntrate 25 minutos sin distracciones.\n'
          '2. Al terminar, toma un descanso corto de 5 minutos.\n'
          '3. Cada 4 pomodoros, el descanso es de 15 minutos.\n\n'
          'Bloques cortos y fijos hacen más fácil empezar y evitan el cansancio. '
          'El ciclo se cierra cuando termina (u omites) el descanso.',
    ),
    Technique.flowtime => (
      '¿Cómo funciona Flowtime?',
      '1. Empieza a estudiar: el cronómetro cuenta hacia arriba.\n'
          '2. Cuando pierdas la concentración, toca "Terminar enfoque". '
          'Necesitas mínimo 10 minutos para que cuente como sesión válida.\n'
          '3. El descanso se ajusta a lo que estudiaste:\n'
          '   • menos de 25 min → 5 min\n'
          '   • 25 a 50 min → 8 min\n'
          '   • 50 a 90 min → 10 min\n'
          '   • más de 90 min → ¼ del tiempo estudiado\n'
          '4. Desde las 2 horas te preguntamos cada hora "¿Sigues ahí?". '
          'Si no respondes en 1 minuto, cerramos el enfoque y empieza el descanso.\n'
          '5. Al terminar el descanso se cierra el ciclo.\n\n'
          'Ideal para proyectos que necesitan concentración profunda.',
    ),
  };
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Mascot(MascotPose.enfoque, size: 70),
      title: Text(title),
      content: SingleChildScrollView(child: Text(body)),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('¡Entendido!'))],
    ),
  );
}
