import 'package:flutter/material.dart';

import '../models/avatar.dart';
import 'avatar_view.dart';

/// Poses del mapache de CronoEdu, en el mismo pixel art de los avatares.
enum MascotPose { escritorio, enfoque, descanso, logro }

class Mascot extends StatelessWidget {
  const Mascot(this.pose, {super.key, this.size = 120});

  final MascotPose pose;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (look, mood) = switch (pose) {
      MascotPose.escritorio => (const AvatarLook(efecto: 'corazones'), AvatarMood.feliz),
      MascotPose.enfoque => (const AvatarLook(cara: 'lentes'), AvatarMood.concentrado),
      MascotPose.descanso => (const AvatarLook(efecto: 'bateria_baja'), AvatarMood.dormido),
      MascotPose.logro => (const AvatarLook(cabeza: 'corona', efecto: 'brillitos'), AvatarMood.feliz),
    };
    return AvatarView(look, size: size, mood: mood, background: false);
  }
}

/// Mensaje vacío con el mapache.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.pose = MascotPose.descanso, this.action});

  final String title;
  final String? message;
  final MascotPose pose;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Mascot(pose, size: 90),
          const SizedBox(height: 12),
          Text(
            title,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, style: t.bodyMedium, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// Pomodoro: el mapache se come un tomate (como el reloj de cocina) y lo
/// termina justo al acabar los 25 minutos. [progress] va de 0 a 1.
class TomatoMascot extends StatelessWidget {
  const TomatoMascot({super.key, required this.progress, this.chewing = false, this.size = 96});

  final double progress;

  /// Alterna la boca abierta y cerrada (masticando).
  final bool chewing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final stage = (progress.clamp(0.0, 1.0) * PixelSprite.tomatoStages).floor();
    return PixelArt(
      PixelSprite.build(
        const AvatarLook(),
        chewing ? AvatarMood.comiendo : AvatarMood.feliz,
        prop: SpriteProp.tomate,
        stage: stage,
      ),
      size: size,
      label: 'Mapache comiéndose un tomate',
    );
  }
}

/// Flowtime en enfoque: estudiando juicioso, con la batería al 100 %.
class StudyingMascot extends StatelessWidget {
  const StudyingMascot({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => PixelArt(
    PixelSprite.build(
      const AvatarLook(cara: 'lentes', efecto: 'bateria_llena'),
      AvatarMood.concentrado,
      prop: SpriteProp.libro,
    ),
    size: size,
    label: 'Mapache estudiando con la batería llena',
  );
}

/// Flowtime en descanso: acostado y dormido. [frame] mueve las "Z".
class SleepingMascot extends StatelessWidget {
  const SleepingMascot({super.key, this.frame = 0, this.size = 96});
  final int frame;
  final double size;

  @override
  Widget build(BuildContext context) => PixelArt(
    PixelSprite.sleeping(const AvatarLook(), frame),
    width: PixelSprite.bedWidth,
    size: size,
    label: 'Mapache durmiendo',
  );
}
