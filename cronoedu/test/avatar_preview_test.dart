import 'dart:io';

import 'package:cronoedu/models/avatar.dart';
import 'package:cronoedu/widgets/avatar_view.dart';
import 'package:cronoedu/widgets/mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vista previa de avatares', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final looks = <(AvatarLook, AvatarMood)>[
      for (final a in AvatarCatalog.ofSlot(AvatarSlot.animal)) (AvatarLook(animal: a.id), AvatarMood.normal),
      for (final c in AvatarCatalog.ofSlot(AvatarSlot.cabeza))
        (AvatarLook(animal: 'gato', cabeza: c.id, fondo: 'cuadricula'), AvatarMood.normal),
      (const AvatarLook(animal: 'pato', efecto: 'en_llamas', fondo: 'rosa'), AvatarMood.normal),
      (const AvatarLook(animal: 'shiba', efecto: 'bateria_baja', fondo: 'menta'), AvatarMood.normal),
      (const AvatarLook(animal: 'zarigueya', efecto: 'corazones', cara: 'curita', fondo: 'cielo'), AvatarMood.normal),
      (
        const AvatarLook(animal: 'gato_negro', efecto: 'brillitos', cara: 'gafas_sol', fondo: 'noche'),
        AvatarMood.normal,
      ),
      (const AvatarLook(animal: 'panda', cabeza: 'disfraz_tiburon', cara: 'lentes'), AvatarMood.normal),
      for (final m in AvatarMood.values) (const AvatarLook(), m),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final (l, m) in looks) AvatarView(l, size: 120, mood: m)],
          ),
        ),
      ),
    );
    expect(find.byType(AvatarView), findsNWidgets(looks.length));
    // Captura solo si se pide: CAPTURAS=1 flutter test --update-goldens
    if (Platform.environment['CAPTURAS'] == null) return;
    await expectLater(find.byType(Wrap), matchesGoldenFile('goldens/60_avatares.png'));
  });

  testWidgets('escenas de la mascota en Técnicas', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i <= PixelSprite.tomatoStages; i++)
                TomatoMascot(progress: i / PixelSprite.tomatoStages, chewing: i.isOdd, size: 140),
              const StudyingMascot(size: 140),
              const SleepingMascot(size: 140),
              const SleepingMascot(frame: 1, size: 140),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(TomatoMascot), findsNWidgets(PixelSprite.tomatoStages + 1));
    if (Platform.environment['CAPTURAS'] == null) return;
    await expectLater(find.byType(Wrap), matchesGoldenFile('goldens/61_mascota_tecnicas.png'));
  });
}
