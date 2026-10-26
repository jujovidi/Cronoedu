import 'package:cronoedu/models/avatar.dart';
import 'package:cronoedu/models/task.dart';
import 'package:cronoedu/services/bellotas_repository.dart';
import 'package:cronoedu/services/storage_service.dart';
import 'package:cronoedu/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor de mentira: anota las llamadas y responde con [state].
class FakeServer implements BellotasRepository {
  final calls = <String>[];
  ServerProfile state = _profile();
  Object? failWith;

  static ServerProfile _profile({int bellotas = 0, int earned = 0, Set<String> owned = const {}}) => ServerProfile(
    name: '',
    career: '',
    semester: 1,
    avatar: const AvatarLook(),
    streakDays: 0,
    lastCycleDay: '',
    bellotas: bellotas,
    bellotasEarned: earned,
    weekPoints: earned,
    ownedItems: owned,
  );

  Future<T> _do<T>(String call, T result) async {
    calls.add(call);
    if (failWith != null) throw failWith!;
    return result;
  }

  @override
  Future<ServerProfile?> load() => _do('load', state);
  @override
  Future<int> earnFocus(int minutes) => _do('enfoque $minutes', minutes ~/ 5);
  @override
  Future<(int, int)> earnCycle() => _do('ciclo', (10, 5));
  @override
  Future<int> earnTask(String taskId, {required bool onTime}) => _do('tarea ${onTime ? 'a tiempo' : 'tarde'}', 0);
  @override
  Future<int> buy(String itemId) => _do('compra $itemId', 0);
  @override
  Future<void> saveProfile({
    required String name,
    required String career,
    required int semester,
    required AvatarLook avatar,
  }) => _do('perfil ${avatar.fondo}', null);
}

void main() {
  late FakeServer server;
  late AppState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = FakeServer();
    state = AppState(await StorageService.open(), bellotasServer: server);
  });

  Future<void> settle() => state.syncFromServer();

  test('el ciclo se manda después del enfoque y lo del servidor reemplaza lo local', () async {
    state.logFocus(const Duration(minutes: 25));
    expect(state.addCycle(pomodoro: true).bellotas, 15); // se ve al instante
    server.state = FakeServer._profile(bellotas: 20, earned: 20);
    await settle();
    expect(server.calls.where((c) => c != 'load'), ['enfoque 25', 'ciclo']);
    expect(state.bellotas, 20);
    expect(state.points, 20);
  });

  test('un enfoque de menos de 5 min no llama al servidor', () async {
    state.logFocus(const Duration(minutes: 4));
    await settle();
    expect(server.calls, ['load']);
  });

  test('tarea completada y compra con el objeto puesto', () async {
    final task = state.addTask(
      subject: 'Cálculo',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      complexity: TaskComplexity.values.first,
    );
    state.setTaskStatus(task, TaskStatus.completada); // 25 bellotas
    expect(state.buyItem(AvatarCatalog.byId('cuadricula')!), isTrue); // cuesta 20
    server.state = FakeServer._profile(bellotas: 5, earned: 25, owned: {'cuadricula'});
    await settle();
    expect(server.calls.where((c) => c != 'load'), ['tarea a tiempo', 'compra cuadricula', 'perfil cuadricula']);
    expect(state.owns(AvatarCatalog.byId('cuadricula')!), isTrue);
    expect(state.bellotas, 5);
  });

  test('si el servidor rechaza la compra, se deshace en el celular', () async {
    state.logFocus(const Duration(minutes: 150)); // 30 bellotas locales
    server.failWith = Exception('No te alcanzan las bellotas');
    expect(state.buyItem(AvatarCatalog.byId('mono')!), isTrue);
    server.failWith = null; // el servidor sigue diciendo 0 bellotas y sin el moñito
    await settle();
    expect(state.owns(AvatarCatalog.byId('mono')!), isFalse);
    expect(state.avatar.cabeza, isNull);
    expect(state.bellotas, 0);
  });

  test('sin internet se queda lo local', () async {
    server.failWith = Exception('sin conexión');
    state.logFocus(const Duration(minutes: 25));
    await settle();
    expect(state.bellotas, 5);
  });

  test('en un celular nuevo el perfil llega del servidor', () async {
    server.state = const ServerProfile(
      name: 'Ana',
      career: 'Ingeniería de Sistemas',
      semester: 4,
      avatar: AvatarLook(animal: 'gato'),
      streakDays: 3,
      lastCycleDay: '2026-10-25',
      bellotas: 50,
      bellotasEarned: 300,
      weekPoints: 40,
      ownedItems: {'gato'},
    );
    await settle();
    expect(state.profile.isRegistered, isTrue);
    expect(state.profile.semester, 4);
    expect(state.level, 3);
    expect(state.weekPoints, 40);
    expect(state.avatar.animal, 'gato');
  });
}
