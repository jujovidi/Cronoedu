import 'package:cronoedu/models/schedule_block.dart';
import 'package:cronoedu/services/planner.dart';
import 'package:cronoedu/services/storage_service.dart';
import 'package:cronoedu/services/study_links.dart';
import 'package:cronoedu/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppState, SharedPreferences)> newState() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return (AppState(StorageService(prefs, namespace: 'c1')), prefs);
  }

  test('agendar una sugerencia guarda materia y tema, y sobrevive al reinicio', () async {
    final (state, prefs) = await newState();
    final start = DateTime.now().add(const Duration(days: 1));
    final day = DateTime(start.year, start.month, start.day, 15);
    final block = state.scheduleSuggestion(
      StudySuggestion(day, day.add(const Duration(hours: 1)), null),
      subject: 'Modelación',
      topic: 'Dinámica de sistemas',
    );
    expect(block.title, 'Estudio: Modelación');
    expect(block.studyLabel, 'Modelación · Dinámica de sistemas');

    final reloaded = AppState(StorageService(prefs, namespace: 'c1'));
    final saved = reloaded.blocks.single;
    expect((saved.subject, saved.topic), ('Modelación', 'Dinámica de sistemas'));
    expect(reloaded.upcomingStudySessions().single.block.id, block.id);
  });

  test('las sesiones guardadas antes de tener materia la toman del título', () {
    final old = ScheduleBlock.fromJson({
      'id': 'x',
      'type': 'estudio',
      'title': 'Estudio: Cálculo',
      'weekday': 2,
      'start': 600,
      'end': 660,
    });
    expect(old.studySubject, 'Cálculo');
    expect(old.topic, '');
    final weekly = ScheduleBlock(
      id: 'y',
      type: BlockType.estudio,
      title: 'Modelacion',
      weekday: 2,
      start: const DayTime(15, 10),
      end: const DayTime(18, 0),
    );
    expect(weekly.studySubject, 'Modelacion');
  });

  test('próximas sesiones: la semanal aparece una vez y la que ya terminó no', () async {
    final (state, _) = await newState();
    final tuesday = DateTime(2026, 11, 3, 16); // martes 16:00
    state.addBlocks(
      type: BlockType.estudio,
      title: 'Estudio: Modelación',
      weekdays: [DateTime.tuesday],
      start: const DayTime(15, 10),
      end: const DayTime(18, 0),
      subject: 'Modelación',
    );
    state.addBlocks(
      type: BlockType.estudio,
      title: 'Estudio: Redes',
      weekdays: [DateTime.monday],
      start: const DayTime(8, 0),
      end: const DayTime(9, 0),
      subject: 'Redes',
    );
    state.addBlocks(
      type: BlockType.ocio,
      title: 'Gym',
      weekdays: [DateTime.tuesday],
      start: const DayTime(18, 0),
      end: const DayTime(19, 0),
    );
    final upcoming = state.upcomingStudySessions(now: tuesday);
    // Modelación sigue en curso hoy; Redes ya pasó el lunes y vuelve el próximo.
    expect(
      [for (final s in upcoming) (s.block.subject, s.day)],
      [('Modelación', DateTime(2026, 11, 3)), ('Redes', DateTime(2026, 11, 9))],
    );
    expect(state.studySessionsOn(DateTime(2026, 11, 3)).single.block.subject, 'Modelación');
    expect(state.upcomingStudySessions(now: DateTime(2026, 11, 3, 18, 30)).first.day, DateTime(2026, 11, 9));
  });

  test('tocar una ficha la pide en Sugerencias', () async {
    final (state, _) = await newState();
    state.openSuggestion('sesion:abc');
    expect(state.tab, AppTab.sugerencias);
    expect(state.suggestionRequest, 'sesion:abc');
    state.clearSuggestionRequest();
    expect(state.suggestionRequest, isNull);
  });

  test('explorar una materia trae más fuentes de artículos', () {
    final links = StudyLinks.forSubject('Modelación');
    final sources = {for (final l in links) l.source};
    expect(sources, containsAll(['YouTube', 'Google Académico', 'SciELO', 'Redalyc', 'Dialnet', 'Wikipedia']));
    expect(links.where((l) => l.kind == StudyLinkKind.articulo).length, greaterThan(5));
  });
}
