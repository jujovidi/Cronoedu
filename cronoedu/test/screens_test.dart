import 'dart:io';

import 'package:cronoedu/main.dart';
import 'package:cronoedu/models/account.dart';
import 'package:cronoedu/models/avatar.dart';
import 'package:cronoedu/models/schedule_block.dart';
import 'package:cronoedu/models/task.dart';
import 'package:cronoedu/services/auth_repository.dart';
import 'package:cronoedu/services/leaderboard_repository.dart';
import 'package:cronoedu/services/password_hasher.dart';
import 'package:cronoedu/services/schedule_pdf_parser.dart';
import 'package:cronoedu/services/storage_service.dart';
import 'package:cronoedu/services/study_material_repository.dart';
import 'package:cronoedu/state/app_state.dart';
import 'package:cronoedu/state/auth_controller.dart';
import 'package:cronoedu/state/study_timer.dart';
import 'package:cronoedu/widgets/block_form.dart';
import 'package:cronoedu/widgets/mascot.dart';
import 'package:cronoedu/widgets/task_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures_reporte_horario.dart';

/// Recorre todas las pantallas con datos de ejemplo. Con
/// `CAPTURAS=1 flutter test --update-goldens` además guarda capturas en
/// test/goldens/ para revisar el diseño.
Future<void> _loadFonts() async {
  final root = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$root/Roboto-$w.ttf').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$root/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

void main() {
  late AppState state;
  late AuthController auth;
  late StudyTimer timer;
  DateTime? fakeNow; // permite adelantar el reloj del temporizador

  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('es');
    StudyMaterialLibrary.instance.debugIndex = StudyMaterialIndex.fromGzip(
      File(StudyMaterialLibrary.asset).readAsBytesSync(),
    );
  });

  Future<void> pumpApp(WidgetTester tester, {ThemeMode mode = ThemeMode.light, bool registered = true}) async {
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final account = Account(
      id: 'cuenta-1',
      nickname: 'juanjo',
      email: 'juanjo@ucundinamarca.edu.co',
      createdAt: DateTime(2026),
    );
    final board = LocalLeaderboardRepository(prefs);
    auth = AuthController(LocalAuthRepository(prefs), board);
    state = AppState(
      StorageService(prefs, namespace: account.id),
      account: account,
      leaderboard: board,
    );
    fakeNow = null;
    timer = StudyTimer(
      clock: () => fakeNow ?? DateTime.now(),
      onCycleCompleted: (t) => state.addCycle(pomodoro: t == Technique.pomodoro),
      onFocusLogged: state.logFocus,
    );
    if (registered) {
      state.updateProfile(name: 'Juan José', career: 'Ingeniería de Sistemas', semester: 9);
      state.markTutorialSeen();
      state.setThemeMode(mode);
      state.importClasses(SchedulePdfParser().parse(reporteHorarioWords).take(7).toList());
      final today = DateUtils.dateOnly(DateTime.now());
      final thursday = today.add(Duration(days: (DateTime.thursday - today.weekday) % 7));
      state.addTask(
        subject: 'Gerencia de Proyectos',
        topic: 'Acta de constitución',
        dueDate: today.add(const Duration(days: 2)),
        dueTime: const DayTime(18, 0),
        complexity: TaskComplexity.proyecto,
        description: 'Entregar el cronograma y el acta de constitución del proyecto.',
      );
      state.addTask(
        subject: 'Modelación',
        topic: 'Taller 3',
        dueDate: thursday,
        delivery: DeliveryMode.fisico,
        complexity: TaskComplexity.tareita,
        description: 'Taller de ecuaciones diferenciales, ejercicios 1 a 10.',
      );
      state.addTask(
        subject: 'Opción de Grado',
        topic: 'Avance anteproyecto',
        dueDate: today,
        complexity: TaskComplexity.tareita,
      );
      final done = state.addTask(
        subject: 'Redes Convergentes',
        topic: 'Quiz',
        dueDate: today,
        complexity: TaskComplexity.tareita,
      );
      state.toggleTask(done);
      state.addTask(
        subject: 'Seguridad Perimetral',
        topic: 'Diseño de firewall',
        dueDate: today.add(const Duration(days: 12)),
        complexity: TaskComplexity.proyectoFinal,
        description: 'Diseño del firewall perimetral para la red del campus.',
      );
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: timer),
        ],
        child: const CronoEduApp(),
      ),
    );
    await tester.runAsync(() async {
      for (final el in find.byType(Image).evaluate()) {
        await precacheImage((el.widget as Image).image, el);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (final el in find.byType(Image).evaluate()) {
        await precacheImage((el.widget as Image).image, el);
      }
    });
    await tester.pump(const Duration(milliseconds: 100));
    // Capturas solo si se pide: CAPTURAS=1 flutter test --update-goldens
    if (Platform.environment['CAPTURAS'] == null) return;
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('registro inicial', (tester) async {
    await pumpApp(tester, registered: false);
    expect(find.text('¡Bienvenido a CronoEdu!'), findsOneWidget);
    await shot(tester, '00_registro');
    await tester.enterText(find.byType(TextFormField).first, 'Ana');
    await tester.tap(find.text('EMPEZAR'));
    await tester.pumpAndSettle();
    expect(find.text('SIGUIENTE'), findsOneWidget); // tutorial
    await shot(tester, '01_tutorial');
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode == ThemeMode.light ? 'claro' : 'oscuro';

    testWidgets('recorrido de pantallas ($suffix)', (tester) async {
      await pumpApp(tester, mode: mode);
      state.profile
        ..bellotas = 185
        ..bellotasEarned = 310
        ..ownedItems.addAll(['lentes', 'disfraz_fresa', 'corazones'])
        ..avatar = const AvatarLook(cabeza: 'disfraz_fresa', efecto: 'corazones', fondo: 'lavanda');
      state.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('¡Hola, Juan!'), findsOneWidget);
      expect(find.textContaining('Nivel'), findsNothing); // el saludo no muestra la gamificación
      await shot(tester, '10_inicio_$suffix');

      Future<void> goTo(String label) async {
        await tester.tap(find.text('Apartados'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, label));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Apartados'));
      await tester.pumpAndSettle();
      await shot(tester, '11_menu_$suffix');
      await tester.tap(find.widgetWithText(ListTile, 'Calendario'));
      await tester.pumpAndSettle();
      await shot(tester, '20_horario_semana_$suffix');
      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
      await shot(tester, '21_horario_mes_$suffix');

      await goTo('Sugerencias');
      expect(find.text('EMPEZAR A ESTUDIAR'), findsWidgets);
      await shot(tester, '30_sugerencias_$suffix');
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      await tester.drag(find.text('Material para estudiar').at(1), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.open_in_new_rounded), findsWidgets);
      await shot(tester, '31_material_estudio_$suffix');
      // Según el día de la semana la tarjeta de Modelación puede quedar fuera
      // de la barra de tareas: se desliza hasta verla.
      final modelacion = find.textContaining('Modelación ·');
      await tester.scrollUntilVisible(
        modelacion,
        100,
        scrollable: find.ancestor(of: find.byType(ChoiceChip).first, matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(modelacion);
      await tester.pumpAndSettle();

      await tester.tap(find.text('EMPEZAR A ESTUDIAR').hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.text('TAREA ACTIVA'), findsOneWidget);
      await shot(tester, '40_tecnicas_listo_$suffix');
      await tester.tap(find.text('EMPEZAR'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 600));
      await shot(tester, '41_tecnicas_enfoque_$suffix');
      await tester.tap(find.text('PAUSAR'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 600));
      await shot(tester, '42_tecnicas_pausa_$suffix');
      timer.resume();
      timer.finishFocus(focusOverride: const Duration(minutes: 25));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 600));
      await shot(tester, '43_tecnicas_descanso_$suffix');
      await tester.ensureVisible(find.text('OMITIR DESCANSO'));
      await tester.tap(find.text('OMITIR DESCANSO'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('¡BIEN HECHO!'), findsOneWidget);
      expect(find.text('+15 bellotas'), findsOneWidget);
      await shot(tester, '44_tecnicas_logro_$suffix');
      expect(state.profile.pomodoroCycles, 1);
      timer.reset();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Perfil').first);
      await tester.pumpAndSettle();
      expect(find.text('Eliminar cuenta'), findsOneWidget);
      await shot(tester, '50_perfil_$suffix');
      await tester.tap(find.text('Mi avatar y ranking'));
      await tester.pumpAndSettle();
      expect(find.text('Nivel 3'), findsOneWidget);
      expect(find.text('@juanjo'), findsOneWidget);
      await shot(tester, '53_recompensas_$suffix');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Disfraces y gorros'));
      await tester.pumpAndSettle();
      await shot(tester, '54_disfraces_$suffix');
      await tester.tap(find.text('Disfraz de rana'));
      await tester.pumpAndSettle();
      await shot(tester, '55_comprar_$suffix');
      await tester.tap(find.text('COMPRAR'));
      await tester.pumpAndSettle();
      expect(state.avatar.cabeza, 'disfraz_rana');
      expect(find.textContaining('Ya tienes Disfraz de rana'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Efectos'));
      await tester.pumpAndSettle();
      await shot(tester, '56_efectos_$suffix');
      await tester.tap(find.text('Ranking'));
      await tester.pumpAndSettle();
      expect(find.text('Tu posición · ${state.points} pts'), findsNothing); // semana: solo lo de esta semana
      expect(find.textContaining('Tu posición'), findsOneWidget);
      await shot(tester, '57_ranking_semana_$suffix');
      await tester.tap(find.text('Todo el tiempo'));
      await tester.pumpAndSettle();
      expect(find.text('Tu posición · ${state.points} pts'), findsOneWidget);
      await shot(tester, '58_ranking_total_$suffix');
      await tester.tap(find.byTooltip('Perfil').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayuda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preguntas'));
      await tester.pumpAndSettle();
      await shot(tester, '51_ayuda_$suffix');
      await tester.tap(find.text('Tutorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VER TUTORIAL PASO A PASO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SIGUIENTE'));
      await tester.pumpAndSettle();
      expect(find.text('Módulo 2 · Tareas'), findsOneWidget);
      await shot(tester, '52_tutorial_modulo_$suffix');
    });
  }

  testWidgets('formularios de tarea y actividad', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Tarea').last);
    await tester.pumpAndSettle();
    await shot(tester, '12_form_tarea');
    await tester.enterText(find.byType(TextFormField).first, 'Cálculo');
    await tester.tap(find.text('GUARDAR TAREA'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el tema'), findsOneWidget); // el tema es obligatorio
    await tester.enterText(find.byType(TextFormField).at(1), 'Parcial 2');
    await tester.tap(find.text('GUARDAR TAREA'));
    await tester.pumpAndSettle();
    expect(state.tasks.where((t) => t.subject == 'Cálculo' && t.topic == 'Parcial 2'), hasLength(1));

    // Días pasados: no abre el formulario.
    final ctx = tester.element(find.byType(Scaffold).first);
    showTaskForm(ctx, date: DateTime.now().subtract(const Duration(days: 1)));
    await tester.pumpAndSettle();
    expect(find.text('Nueva tarea'), findsNothing);
    expect(find.textContaining('fechas pasadas'), findsOneWidget);

    // Aviso de hora de inicio igual a la de fin.
    showBlockForm(
      ctx,
      block: ScheduleBlock(
        id: 'x',
        type: BlockType.trabajo,
        title: 'Turno',
        weekday: 2,
        start: const DayTime(14, 0),
        end: const DayTime(14, 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no pueden ser iguales'), findsOneWidget);
    await shot(tester, '23_aviso_horas');
    Navigator.of(tester.element(find.text('Turno'))).pop();
    await tester.pumpAndSettle();

    state.selectTab(AppTab.horario);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).hitTestable().first, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocio').hitTestable().last);
    await tester.pumpAndSettle();
    await shot(tester, '22_form_ocio');

    state.selectTab(AppTab.horario);
    await tester.pumpAndSettle();
  });

  testWidgets('Flowtime: mínimo de 10 min y ¿Sigues ahí?', (tester) async {
    await pumpApp(tester);
    state.selectTab(AppTab.tecnicas);
    timer.selectTechnique(Technique.flowtime);
    await tester.pumpAndSettle();
    timer.start();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('para que la sesión sea válida'), findsOneWidget);
    await shot(tester, '45_flowtime_minimo');

    await tester.tap(find.text('TERMINAR ENFOQUE'));
    await tester
        .pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5))
        .catchError((_) => 0);
    expect(find.text('Aún no cuenta como sesión'), findsOneWidget);
    await tester.tap(find.text('Seguir estudiando'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 600));

    fakeNow = DateTime.now().add(const Duration(hours: 2, seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('¿Sigues ahí?'), findsOneWidget);
    await shot(tester, '46_flowtime_sigues_ahi');
    await tester.tap(find.text('¡SÍ, SIGO AQUÍ!'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('¿Sigues ahí?'), findsNothing);
    await tester.tap(find.text('TERMINAR ENFOQUE'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('DESCANSO'), findsOneWidget);
    expect(find.byType(SleepingMascot), findsOneWidget);
    await shot(tester, '47_flowtime_descanso');
    timer.reset();
    await tester.pumpAndSettle();
  });

  testWidgets('crear cuenta, cerrar sesión y volver a entrar', (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authCtl = AuthController(
      LocalAuthRepository(prefs, hasher: const PasswordHasher(iterations: 50)),
      LocalLeaderboardRepository(prefs),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: authCtl,
        child: CronoEduRoot(prefs: prefs),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ENTRAR'), findsOneWidget);
    await shot(tester, '02_iniciar_sesion');

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'lunita_studies'); // nickname de ejemplo, ya usado
    await tester.enterText(fields.at(1), 'ana@ucundinamarca.edu.co');
    await tester.enterText(fields.at(2), 'clave1234');
    await tester.enterText(fields.at(3), 'clave1234');
    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pumpAndSettle();
    expect(find.text('Ese nickname ya está en uso. Prueba con otro.'), findsOneWidget);
    await shot(tester, '03_crear_cuenta');

    await tester.enterText(fields.at(0), 'ana.dev');
    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pumpAndSettle();
    expect(find.text('¡Bienvenido a CronoEdu!'), findsOneWidget);
    expect(prefs.getString('accounts'), isNot(contains('clave1234'))); // solo el hash

    await authCtl.logout();
    await tester.pumpAndSettle();
    expect(find.text('ENTRAR'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'ANA.DEV');
    await tester.enterText(find.byType(TextFormField).at(1), 'otra-clave1');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();
    expect(find.text('Correo, nickname o contraseña incorrectos.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'clave1234');
    await tester.tap(find.text('ENTRAR'));
    await tester.pumpAndSettle();
    expect(authCtl.account?.nickname, 'ana.dev');
    expect(find.text('¡Bienvenido a CronoEdu!'), findsOneWidget);
  });
}
