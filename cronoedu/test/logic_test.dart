import 'package:cronoedu/models/schedule_block.dart';
import 'package:cronoedu/models/task.dart';
import 'package:cronoedu/services/planner.dart';
import 'package:cronoedu/state/study_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flowtime', () {
    late DateTime now;
    late StudyTimer timer;
    late List<Technique> cycles;
    late List<Duration> logged;

    setUp(() {
      now = DateTime(2026, 10, 20, 8);
      cycles = [];
      logged = [];
      timer = StudyTimer(clock: () => now, onCycleCompleted: cycles.add, onFocusLogged: logged.add)
        ..selectTechnique(Technique.flowtime);
    });
    tearDown(() => timer.dispose());

    test('menos de 10 minutos no cuenta como sesión', () {
      timer.start();
      now = now.add(const Duration(minutes: 9));
      expect(timer.focusIsValid, isFalse);
      expect(timer.finishFocus(), isFalse);
      expect(timer.phase, TimerPhase.enfoque);
      now = now.add(const Duration(minutes: 1));
      expect(timer.finishFocus(), isTrue);
      expect(timer.phase, TimerPhase.descanso);
      expect(logged, [const Duration(minutes: 10)]);
    });

    test('el ciclo se cierra al terminar el descanso', () {
      timer.start();
      now = now.add(const Duration(minutes: 30));
      timer.finishFocus();
      expect(cycles, isEmpty);
      expect(timer.display, const Duration(minutes: 8));
      now = now.add(const Duration(minutes: 8));
      timer.tick();
      expect(timer.phase, TimerPhase.logro);
      expect(cycles, [Technique.flowtime]);
      expect(timer.sessionCycles, 1);
    });

    test('más de 90 minutos: descanso de 1/4', () {
      expect(timer.breakFor(const Duration(minutes: 120)), const Duration(minutes: 30));
      expect(timer.breakFor(const Duration(minutes: 90)), const Duration(minutes: 10));
      expect(timer.breakFor(const Duration(minutes: 49)), const Duration(minutes: 8));
    });

    test('"¿Sigues ahí?" a las 2 h y luego cada hora', () {
      timer.start();
      now = now.add(const Duration(hours: 1, minutes: 59));
      expect(timer.awaitingPresence, isFalse);
      now = now.add(const Duration(minutes: 1));
      expect(timer.awaitingPresence, isTrue);
      timer.confirmPresence();
      expect(timer.awaitingPresence, isFalse);
      now = now.add(const Duration(minutes: 59));
      expect(timer.awaitingPresence, isFalse);
      now = now.add(const Duration(minutes: 1));
      expect(timer.awaitingPresence, isTrue); // 3 h
    });

    test('sin respuesta en 1 minuto termina el enfoque en el punto de la pregunta', () {
      timer.start();
      now = now.add(const Duration(hours: 2, seconds: 30));
      timer.tick();
      expect(timer.phase, TimerPhase.enfoque);
      expect(timer.presenceTimeLeft, const Duration(seconds: 30));
      now = now.add(const Duration(seconds: 30));
      timer.tick();
      expect(timer.phase, TimerPhase.descanso);
      expect(timer.endedByAbsence, isTrue);
      expect(timer.lastFocus, const Duration(hours: 2));
      expect(timer.display, const Duration(minutes: 30)); // 1/4 de 2 h
    });

    test('próximas preguntas para las notificaciones', () {
      timer.start();
      final checks = timer.upcomingPresenceChecks(count: 2);
      expect(checks, [DateTime(2026, 10, 20, 10), DateTime(2026, 10, 20, 11)]);
    });
  });

  group('Pomodoro', () {
    test('descanso largo en el 4º ciclo', () {
      var now = DateTime(2026, 10, 20, 8);
      final timer = StudyTimer(clock: () => now);
      for (var i = 0; i < 3; i++) {
        timer.start();
        now = now.add(StudyTimer.pomodoroFocus);
        timer.tick();
        expect(timer.display, StudyTimer.pomodoroShortBreak);
        timer.skipBreak();
      }
      timer.start();
      now = now.add(StudyTimer.pomodoroFocus);
      timer.tick();
      expect(timer.display, StudyTimer.pomodoroLongBreak);
      timer.dispose();
    });
  });

  group('Sugerencias de estudio', () {
    const planner = Planner();
    final monday = DateTime(2026, 10, 19, 6); // lunes 6:00
    final task = Task(
      id: 't',
      subject: 'Cálculo',
      dueDate: DateTime(2026, 10, 23),
      complexity: TaskComplexity.proyecto,
    );
    final clase = ScheduleBlock(
      id: 'c',
      type: BlockType.clase,
      title: 'Cálculo',
      weekday: 1,
      start: const DayTime(7, 0),
      end: const DayTime(9, 0),
    );

    test('una hora por día en el primer espacio libre, hasta la entrega', () {
      final s = planner.studySuggestions([task], [clase], now: monday);
      expect(s.first.start, DateTime(2026, 10, 19, 9));
      expect(s.first.end, DateTime(2026, 10, 19, 10));
      expect(s.map((x) => x.start.day), [19, 20, 21, 22, 23]);
    });

    test('procrastinar descarta el día y agendar evita otra sugerencia', () {
      final agendada = ScheduleBlock(
        id: 'e',
        type: BlockType.estudio,
        title: 'Estudio',
        weekday: 2,
        start: const DayTime(7, 0),
        end: const DayTime(8, 0),
        date: DateTime(2026, 10, 20),
      );
      final s = planner.studySuggestions(
        [task],
        [clase, agendada],
        now: monday,
        dismissed: {StudySuggestion.keyFor(DateTime(2026, 10, 21))},
      );
      expect(s.map((x) => x.start.day), [19, 22, 23]);
    });

    test('las sesiones agendadas solo ocupan su fecha', () {
      final agendada = ScheduleBlock(
        id: 'e',
        type: BlockType.estudio,
        title: 'Estudio',
        weekday: 1,
        start: const DayTime(9, 0),
        end: const DayTime(10, 0),
        date: DateTime(2026, 10, 19),
      );
      expect(planner.freeSlotsOn(DateTime(2026, 10, 19), [agendada]).first.end.hour, 9);
      expect(planner.freeSlotsOn(DateTime(2026, 10, 26), [agendada]).single.start.hour, 7);
    });

    test('sin tareas pendientes no hay sugerencias', () {
      final done = Task(id: 'd', subject: 'X', dueDate: DateTime(2026, 10, 23), complexity: TaskComplexity.tareita)
        ..status = TaskStatus.completada;
      expect(planner.studySuggestions([done], const [], now: monday), isEmpty);
    });
  });
}
