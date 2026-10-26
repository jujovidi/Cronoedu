import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar.dart';

enum LeaderboardPeriod {
  semana('Esta semana'),
  total('Todo el tiempo');

  const LeaderboardPeriod(this.label);
  final String label;
}

/// Una fila del ranking. Los puntos son las bellotas ganadas (no bajan al
/// gastar en la tienda).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.accountId,
    required this.nickname,
    required this.avatar,
    required this.points,
    required this.weekPoints,
    required this.weekKey,
    this.demo = false,
  });

  final String accountId;
  final String nickname;
  final AvatarLook avatar;
  final int points;
  final int weekPoints;

  /// Lunes de la semana de [weekPoints] ("aaaa-mm-dd").
  final String weekKey;

  /// Estudiante de ejemplo (solo mientras no hay base de datos).
  final bool demo;

  int pointsFor(LeaderboardPeriod p) => switch (p) {
    LeaderboardPeriod.total => points,
    LeaderboardPeriod.semana => weekKey == currentWeekKey() ? weekPoints : 0,
  };

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'nickname': nickname,
    'avatar': avatar.toJson(),
    'points': points,
    'weekPoints': weekPoints,
    'weekKey': weekKey,
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
    accountId: j['accountId'] as String,
    nickname: j['nickname'] as String,
    avatar: AvatarLook.fromJson(j['avatar'] as Map<String, dynamic>?),
    points: (j['points'] as int?) ?? 0,
    weekPoints: (j['weekPoints'] as int?) ?? 0,
    weekKey: (j['weekKey'] as String?) ?? '',
  );
}

String currentWeekKey([DateTime? now]) {
  final d = DateUtils.dateOnly(now ?? DateTime.now());
  return d.subtract(Duration(days: d.weekday - 1)).toIso8601String().substring(0, 10);
}

/// Lo que la app necesita del ranking global. Hoy es local; con base de
/// datos, [publish] subirá el puntaje y [fetch] traerá el de todos.
abstract class LeaderboardRepository {
  Future<void> publish(LeaderboardEntry entry);
  Future<List<LeaderboardEntry>> fetch(LeaderboardPeriod period);
  Future<void> remove(String accountId);
}

/// Ranking guardado en el celular: todas las cuentas creadas aquí y, para
/// que se pueda probar, un grupo de estudiantes de ejemplo.
class LocalLeaderboardRepository implements LeaderboardRepository {
  LocalLeaderboardRepository(this._prefs, {this.includeDemo = true});

  static const _key = 'leaderboard';
  final SharedPreferences _prefs;
  final bool includeDemo;

  static Set<String> get demoNicknames => _demo.map((d) => d.nickname.toLowerCase()).toSet();

  Map<String, dynamic> _read() {
    final raw = _prefs.getString(_key);
    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> publish(LeaderboardEntry entry) async {
    final all = _read()..[entry.accountId] = entry.toJson();
    await _prefs.setString(_key, jsonEncode(all));
  }

  @override
  Future<void> remove(String accountId) async {
    final all = _read()..remove(accountId);
    await _prefs.setString(_key, jsonEncode(all));
  }

  @override
  Future<List<LeaderboardEntry>> fetch(LeaderboardPeriod period) async {
    final list = [
      for (final v in _read().values) LeaderboardEntry.fromJson(v as Map<String, dynamic>),
      if (includeDemo) ..._demo,
    ];
    list.sort((a, b) {
      final d = b.pointsFor(period).compareTo(a.pointsFor(period));
      return d != 0 ? d : a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase());
    });
    return list;
  }

  static final _demo = [
    _d('lunita_studies', 1480, 210, const AvatarLook(animal: 'gato', cabeza: 'disfraz_fresa', fondo: 'rosa')),
    _d('tiburon.ing', 1210, 160, const AvatarLook(animal: 'gato_negro', cabeza: 'disfraz_tiburon', fondo: 'cielo')),
    _d('patito_en_llamas', 960, 245, const AvatarLook(animal: 'pato', efecto: 'en_llamas', fondo: 'cuadricula')),
    _d('capi_relax', 720, 60, const AvatarLook(animal: 'capibara', cabeza: 'flor', fondo: 'menta')),
    _d('shiba_dormilon', 540, 95, const AvatarLook(animal: 'shiba', efecto: 'bateria_baja', fondo: 'menta')),
    _d('panda_calculo', 430, 120, const AvatarLook(animal: 'panda', cara: 'lentes', fondo: 'lavanda')),
    _d('zari.grita', 310, 70, const AvatarLook(animal: 'zarigueya', cabeza: 'mono', fondo: 'rosa')),
    _d('mapachito99', 180, 40, const AvatarLook(cabeza: 'gorro_lana', fondo: 'cuadricula')),
    _d('ranita_uwu', 90, 25, const AvatarLook(animal: 'gato', cabeza: 'disfraz_rana', fondo: 'menta')),
  ];

  static LeaderboardEntry _d(String nick, int points, int week, AvatarLook look) => LeaderboardEntry(
    accountId: 'demo:$nick',
    nickname: nick,
    avatar: look,
    points: points,
    weekPoints: week,
    weekKey: currentWeekKey(),
    demo: true,
  );
}
