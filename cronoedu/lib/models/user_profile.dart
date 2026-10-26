import 'package:flutter/material.dart';

import 'avatar.dart';

class UserProfile {
  UserProfile({
    this.name = '',
    this.career = '',
    this.semester = 1,
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
    this.pomodoroCycles = 0,
    this.flowtimeCycles = 0,
    this.tutorialSeen = false,
    this.showStudySuggestions = true,
    this.studyDay = '',
    this.studyMinutesToday = 0,
    this.totalStudyMinutes = 0,
    this.bellotas = 0,
    this.bellotasEarned = 0,
    Set<String>? ownedItems,
    this.avatar = const AvatarLook(),
    Set<String>? rewardedTasks,
    this.streakDays = 0,
    this.lastCycleDay = '',
    this.weekKey = '',
    this.weekPoints = 0,
  }) : ownedItems = ownedItems ?? AvatarCatalog.freeIds,
       rewardedTasks = rewardedTasks ?? {};

  String name;
  String career;
  int semester;
  bool notificationsEnabled;
  ThemeMode themeMode;
  int pomodoroCycles;
  int flowtimeCycles;
  bool tutorialSeen;

  /// Mostrar las horas sugeridas de estudio autónomo en el calendario.
  bool showStudySuggestions;

  /// Minutos de enfoque de hoy ([studyDay] = "aaaa-mm-dd").
  String studyDay;
  int studyMinutesToday;
  int totalStudyMinutes;

  /// Bellotas disponibles para gastar en la tienda del avatar.
  int bellotas;

  /// Bellotas ganadas en total (no baja al comprar); define el nivel.
  int bellotasEarned;

  /// Animales, accesorios y fondos comprados.
  Set<String> ownedItems;
  AvatarLook avatar;

  /// Tareas que ya dieron recompensa (para no cobrarla dos veces).
  Set<String> rewardedTasks;

  /// Días seguidos con al menos un ciclo completo; [lastCycleDay] = "aaaa-mm-dd".
  int streakDays;
  String lastCycleDay;

  /// Puntos de la semana [weekKey] (lunes, "aaaa-mm-dd") para el ranking semanal.
  String weekKey;
  int weekPoints;

  bool get isRegistered => name.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'name': name,
    'career': career,
    'semester': semester,
    'notificationsEnabled': notificationsEnabled,
    'themeMode': themeMode.name,
    'pomodoroCycles': pomodoroCycles,
    'flowtimeCycles': flowtimeCycles,
    'tutorialSeen': tutorialSeen,
    'showStudySuggestions': showStudySuggestions,
    'studyDay': studyDay,
    'studyMinutesToday': studyMinutesToday,
    'totalStudyMinutes': totalStudyMinutes,
    'bellotas': bellotas,
    'bellotasEarned': bellotasEarned,
    'ownedItems': ownedItems.toList(),
    'avatar': avatar.toJson(),
    'rewardedTasks': rewardedTasks.toList(),
    'streakDays': streakDays,
    'lastCycleDay': lastCycleDay,
    'weekKey': weekKey,
    'weekPoints': weekPoints,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: (json['name'] as String?) ?? '',
    career: (json['career'] as String?) ?? '',
    semester: (json['semester'] as int?) ?? 1,
    notificationsEnabled: (json['notificationsEnabled'] as bool?) ?? true,
    themeMode: ThemeMode.values.byName((json['themeMode'] as String?) ?? ThemeMode.system.name),
    pomodoroCycles: (json['pomodoroCycles'] as int?) ?? 0,
    flowtimeCycles: (json['flowtimeCycles'] as int?) ?? 0,
    tutorialSeen: (json['tutorialSeen'] as bool?) ?? false,
    showStudySuggestions: (json['showStudySuggestions'] as bool?) ?? true,
    studyDay: (json['studyDay'] as String?) ?? '',
    studyMinutesToday: (json['studyMinutesToday'] as int?) ?? 0,
    totalStudyMinutes: (json['totalStudyMinutes'] as int?) ?? 0,
    bellotas: (json['bellotas'] as int?) ?? 0,
    bellotasEarned: (json['bellotasEarned'] as int?) ?? 0,
    ownedItems: {
      ...AvatarCatalog.freeIds,
      ...?(json['ownedItems'] as List?)?.cast<String>().where((id) => AvatarCatalog.byId(id) != null),
    },
    avatar: AvatarLook.fromJson(json['avatar'] as Map<String, dynamic>?),
    rewardedTasks: {...?(json['rewardedTasks'] as List?)?.cast<String>()},
    streakDays: (json['streakDays'] as int?) ?? 0,
    lastCycleDay: (json['lastCycleDay'] as String?) ?? '',
    weekKey: (json['weekKey'] as String?) ?? '',
    weekPoints: (json['weekPoints'] as int?) ?? 0,
  );
}
