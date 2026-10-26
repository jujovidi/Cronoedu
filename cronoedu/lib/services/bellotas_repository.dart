import '../models/avatar.dart';

/// Bellotas, racha, tienda y perfil tal como los tiene el servidor.
class ServerProfile {
  const ServerProfile({
    required this.name,
    required this.career,
    required this.semester,
    required this.avatar,
    required this.streakDays,
    required this.lastCycleDay,
    required this.bellotas,
    required this.bellotasEarned,
    required this.weekPoints,
    required this.ownedItems,
  });

  final String name;
  final String career;
  final int semester;
  final AvatarLook avatar;
  final int streakDays;

  /// "aaaa-mm-dd" o '' si nunca completó un ciclo.
  final String lastCycleDay;
  final int bellotas;
  final int bellotasEarned;
  final int weekPoints;
  final Set<String> ownedItems;

  factory ServerProfile.fromJson(Map<String, dynamic> j) => ServerProfile(
    name: (j['nombre'] as String?) ?? '',
    career: (j['carrera'] as String?) ?? '',
    semester: (j['semestre'] as int?) ?? 1,
    avatar: AvatarLook.fromJson(j['avatar'] as Map<String, dynamic>?),
    streakDays: (j['racha'] as int?) ?? 0,
    lastCycleDay: (j['ultimo_dia_racha'] as String?) ?? '',
    bellotas: (j['bellotas'] as int?) ?? 0,
    bellotasEarned: (j['ganadas'] as int?) ?? 0,
    weekPoints: (j['puntos_semana'] as int?) ?? 0,
    ownedItems: {...?(j['objetos'] as List?)?.cast<String>()},
  );
}

/// Lo que la app necesita del servidor para las bellotas. El servidor aplica
/// las reglas de [Rewards] y es quien tiene la última palabra: después de cada
/// acción la app vuelve a leer [load] y corrige lo que haya sumado por su
/// cuenta. Sin servidor (null en [AppState]) todo queda en el celular.
abstract class BellotasRepository {
  Future<ServerProfile?> load();

  /// Fin de un enfoque. Devuelve las bellotas ganadas.
  Future<int> earnFocus(int minutes);

  /// Fin del descanso. Devuelve (bellotas del ciclo, bono de racha).
  Future<(int, int)> earnCycle();

  /// Tarea completada. Devuelve 0 si ya había pagado.
  Future<int> earnTask(String taskId, {required bool onTime});

  /// Compra un objeto de la tienda. Devuelve el saldo nuevo.
  Future<int> buy(String itemId);

  /// Nombre, carrera, semestre y avatar puesto.
  Future<void> saveProfile({
    required String name,
    required String career,
    required int semester,
    required AvatarLook avatar,
  });
}
