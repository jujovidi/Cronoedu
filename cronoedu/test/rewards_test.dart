import 'package:cronoedu/models/avatar.dart';
import 'package:cronoedu/models/task.dart';
import 'package:cronoedu/models/user_profile.dart';
import 'package:cronoedu/services/auth_repository.dart';
import 'package:cronoedu/services/leaderboard_repository.dart';
import 'package:cronoedu/services/password_hasher.dart';
import 'package:cronoedu/services/rewards.dart';
import 'package:cronoedu/services/storage_service.dart';
import 'package:cronoedu/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(await StorageService.open());
  });

  AvatarItem item(String id) => AvatarCatalog.byId(id)!;

  test('un ciclo válido da bellotas por ciclo, minutos y racha', () {
    state.logFocus(const Duration(minutes: 25));
    final r = state.addCycle(pomodoro: true);
    expect(r.bellotas, Rewards.cycle + 5); // 10 + 25 min / 5
    expect(r.streakBonus, Rewards.streakPerDay);
    expect(state.bellotas, 20);
    expect(state.streakDays, 1);

    // El segundo ciclo del día no repite el bono de racha.
    state.logFocus(const Duration(minutes: 25));
    expect(state.addCycle(pomodoro: true).streakBonus, 0);
    expect(state.bellotas, 35);
  });

  test('un ciclo de menos de 10 min solo paga los minutos', () {
    state.logFocus(const Duration(minutes: 9));
    final r = state.addCycle(pomodoro: true);
    expect(r.isEmpty, isTrue);
    expect(state.bellotas, 1);
    expect(state.profile.pomodoroCycles, 1);
  });

  test('la racha crece si ayer también hubo ciclo', () {
    final yesterday = DateUtils.dateOnly(DateTime.now().subtract(const Duration(days: 1)));
    state.profile
      ..lastCycleDay = yesterday.toIso8601String().substring(0, 10)
      ..streakDays = 3;
    state.logFocus(const Duration(minutes: 10));
    expect(state.addCycle(pomodoro: false).streakBonus, 20);
    expect(state.streakDays, 4);
  });

  test('una tarea paga una sola vez y da extra si es a tiempo', () {
    final onTime = state.addTask(
      subject: 'Cálculo',
      topic: 'Taller',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      complexity: TaskComplexity.tareita,
    );
    expect(state.toggleTask(onTime).total, Rewards.task + Rewards.taskOnTime);
    state.toggleTask(onTime); // vuelve a pendiente
    expect(state.toggleTask(onTime).total, 0);
    expect(state.bellotas, 25);

    final late = state.addTask(
      subject: 'Física',
      topic: 'Informe',
      dueDate: DateTime.now().subtract(const Duration(days: 2)),
      complexity: TaskComplexity.tareita,
    );
    expect(state.setTaskStatus(late, TaskStatus.completada).total, Rewards.task);
  });

  test('niveles cada 120 bellotas ganadas; gastar no baja de nivel', () {
    expect(state.level, 1);
    state.profile
      ..bellotas = 130
      ..bellotasEarned = 130;
    expect(state.level, 2);
    expect(state.buyItem(item('zarigueya')), isTrue);
    expect(state.bellotas, 70);
    expect(state.level, 2);
    expect(state.avatar.animal, 'zarigueya');
  });

  test('la tienda respeta saldo, nivel y lo que ya se tiene', () {
    expect(state.buyItem(item('mono')), isFalse); // sin bellotas
    state.profile.bellotas = 1000;
    expect(state.buyItem(item('corona')), isFalse); // nivel 8
    expect(state.isLocked(item('corona')), isTrue);
    expect(state.buyItem(item('mono')), isTrue);
    expect(state.buyItem(item('mono')), isFalse); // ya es suyo
    expect(state.avatar.cabeza, 'mono');

    state.toggleEquip(item('mono'));
    expect(state.avatar.cabeza, isNull);
    state.toggleEquip(item('mono'));
    expect(state.avatar.cabeza, 'mono');

    // El animal no se puede "quitar".
    state.toggleEquip(item('mapache'));
    expect(state.avatar.animal, 'mapache');
  });

  test('el avatar y las compras se guardan', () {
    final p = UserProfile(
      bellotas: 5,
      bellotasEarned: 300,
      ownedItems: {'mono', 'pato', 'bufanda'},
      avatar: const AvatarLook(animal: 'pato', cabeza: 'mono', efecto: 'en_llamas', fondo: 'menta'),
      rewardedTasks: {'t1'},
      streakDays: 2,
      lastCycleDay: '2026-10-19',
    );
    final back = UserProfile.fromJson(p.toJson());
    expect(back.avatar, p.avatar);
    expect(back.ownedItems, containsAll(['mono', 'pato', 'mapache', 'lavanda']));
    expect(back.ownedItems, isNot(contains('bufanda'))); // ya no existe en la tienda
    expect(back.rewardedTasks, {'t1'});
    expect(back.bellotasEarned, 300);
    expect(UserProfile.fromJson({}).avatar, const AvatarLook());
    // Avatares guardados con objetos que ya no existen vuelven a lo básico.
    expect(AvatarLook.fromJson({'animal': 'perro', 'cabeza': 'gorra', 'fondo': 'morado'}), const AvatarLook());
  });

  test('los puntos de la semana se reinician cada lunes', () {
    state.profile
      ..weekKey = '2000-01-03'
      ..weekPoints = 99;
    state.logFocus(const Duration(minutes: 10));
    expect(state.weekPoints, 2);
    expect(state.profile.weekKey, currentWeekKey());
  });

  group('cuentas', () {
    late SharedPreferences prefs;
    late LocalAuthRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'tasks': '[]', 'profile': '{"name":"Juan","bellotas":40}'});
      prefs = await SharedPreferences.getInstance();
      repo = LocalAuthRepository(prefs, hasher: const PasswordHasher(iterations: 50));
    });

    test('registro guarda solo el hash y adopta los datos de antes', () async {
      final a = await repo.register(nickname: 'juanjo', email: 'JuanJo@Ucundinamarca.edu.co', password: 'clave1234');
      expect(a.email, 'juanjo@ucundinamarca.edu.co');
      expect(prefs.getString('accounts'), isNot(contains('clave1234')));
      expect(prefs.getString('profile'), isNull);
      expect(StorageService(prefs, namespace: a.id).loadProfile().bellotas, 40);
      expect(repo.currentAccount?.id, a.id);
    });

    test('nickname y correo únicos, reglas de contraseña', () async {
      await repo.register(nickname: 'juanjo', email: 'a@b.co', password: 'clave1234');
      expect(
        () => repo.register(nickname: 'JUANJO', email: 'c@d.co', password: 'clave1234'),
        throwsA(isA<AuthException>()),
      );
      expect(
        () => repo.register(nickname: 'otro', email: 'A@B.co', password: 'clave1234'),
        throwsA(isA<AuthException>()),
      );
      expect(() => repo.register(nickname: 'otro', email: 'x@y.co', password: 'corta'), throwsA(isA<AuthException>()));
      expect(await repo.nicknameAvailable('lunita_studies'), isFalse); // ejemplo del ranking
    });

    test('entrar con correo o nickname; contraseña incorrecta falla', () async {
      await repo.register(nickname: 'juanjo', email: 'a@b.co', password: 'clave1234');
      await repo.logout();
      expect(repo.currentAccount, isNull);
      expect((await repo.login(user: 'JuanJo', password: 'clave1234')).nickname, 'juanjo');
      expect((await repo.login(user: 'a@b.co', password: 'clave1234')).nickname, 'juanjo');
      expect(() => repo.login(user: 'juanjo', password: 'clave12345'), throwsA(isA<AuthException>()));
    });

    test('cada cuenta tiene sus datos y borrar la cuenta la saca del ranking', () async {
      final board = LocalLeaderboardRepository(prefs, includeDemo: false);
      final a = await repo.register(nickname: 'ana', email: 'ana@x.co', password: 'clave1234');
      final b = await repo.register(nickname: 'beto', email: 'beto@x.co', password: 'clave1234');
      final sa = AppState(
        StorageService(prefs, namespace: a.id),
        account: a,
        leaderboard: board,
      );
      final sb = AppState(
        StorageService(prefs, namespace: b.id),
        account: b,
        leaderboard: board,
      );
      expect(sa.profile.bellotas, 40); // la primera cuenta se quedó con los datos de antes
      expect(sb.profile.bellotas, 0);
      sb.logFocus(const Duration(minutes: 50));
      await sb.publishScore();
      await sa.publishScore();
      final ranking = await board.fetch(LeaderboardPeriod.total);
      expect(ranking.map((e) => e.nickname), ['beto', 'ana']);
      await repo.deleteAccount(b.id);
      expect((await board.fetch(LeaderboardPeriod.total)).map((e) => e.nickname), ['ana']);
      expect(prefs.getKeys().where((k) => k.startsWith('u:${b.id}:')), isEmpty);
    });
  });
}
