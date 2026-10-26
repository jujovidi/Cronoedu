/// Reglas de las bellotas (la moneda del avatar) y de los niveles.
class Rewards {
  /// Ciclo completo (enfoque de al menos [minCycleFocusMinutes] + descanso).
  static const cycle = 10;
  static const minCycleFocusMinutes = 10;

  /// Una bellota por cada 5 minutos de enfoque.
  static const focusMinutesPerBellota = 5;

  /// Tarea completada, y extra si se entrega a tiempo.
  static const task = 15;
  static const taskOnTime = 10;

  /// Primer ciclo del día: 5 bellotas por cada día de racha, hasta 25.
  static const streakPerDay = 5;
  static const streakMax = 25;

  /// Bellotas ganadas que se necesitan para subir cada nivel.
  static const perLevel = 120;

  static int levelFor(int earned) => 1 + earned ~/ perLevel;

  /// Avance (0–1) hacia el siguiente nivel.
  static double levelProgress(int earned) => (earned % perLevel) / perLevel;

  static int toNextLevel(int earned) => perLevel - earned % perLevel;

  static int streakBonus(int streakDays) => (streakDays * streakPerDay).clamp(0, streakMax);
}

/// Lo que se ganó en una acción, para mostrarlo en pantalla.
class Reward {
  const Reward({this.bellotas = 0, this.streakBonus = 0, this.newLevel});

  final int bellotas;
  final int streakBonus;

  /// Nivel alcanzado si esta recompensa hizo subir de nivel.
  final int? newLevel;

  int get total => bellotas + streakBonus;
  bool get isEmpty => total == 0;
}
