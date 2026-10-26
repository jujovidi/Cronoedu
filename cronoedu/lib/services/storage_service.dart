import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_block.dart';
import '../models/task.dart';
import '../models/user_profile.dart';

/// Guarda todo localmente en el dispositivo (sin nube) como JSON. Cada
/// cuenta tiene sus propias claves (`u:<id>:tasks`, …).
class StorageService {
  StorageService(this._prefs, {this.namespace = ''});

  /// Id de la cuenta dueña de los datos ('' = sin cuenta, solo en pruebas).
  final String namespace;

  static const _kTasks = 'tasks';
  static const _kBlocks = 'blocks';
  static const _kProfile = 'profile';

  /// Sugerencias descartadas ("Procrastinar"). Es pública porque también la
  /// escribe el manejador de notificaciones en segundo plano.
  static const kDismissed = 'dismissedSuggestions';

  final SharedPreferences _prefs;

  static Future<StorageService> open({String namespace = ''}) async =>
      StorageService(await SharedPreferences.getInstance(), namespace: namespace);

  String _k(String key) => namespace.isEmpty ? key : 'u:$namespace:$key';

  /// Pasa los datos de antes del inicio de sesión a la cuenta [accountId].
  static Future<void> adoptLegacyData(SharedPreferences prefs, String accountId) async {
    for (final key in [_kTasks, _kBlocks, _kProfile]) {
      final value = prefs.getString(key);
      if (value == null) continue;
      await prefs.setString('u:$accountId:$key', value);
      await prefs.remove(key);
    }
  }

  List<Task> loadTasks() => _readList(_k(_kTasks)).map(Task.fromJson).toList();

  List<ScheduleBlock> loadBlocks() => _readList(_k(_kBlocks)).map(ScheduleBlock.fromJson).toList();

  UserProfile loadProfile() {
    final raw = _prefs.getString(_k(_kProfile));
    if (raw == null) return UserProfile();
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveTasks(List<Task> tasks) =>
      _prefs.setString(_k(_kTasks), jsonEncode(tasks.map((t) => t.toJson()).toList()));

  Future<void> saveBlocks(List<ScheduleBlock> blocks) =>
      _prefs.setString(_k(_kBlocks), jsonEncode(blocks.map((b) => b.toJson()).toList()));

  Future<void> saveProfile(UserProfile profile) => _prefs.setString(_k(_kProfile), jsonEncode(profile.toJson()));

  Set<String> loadDismissedSync() => (_prefs.getStringList(kDismissed) ?? const []).toSet();

  Future<Set<String>> loadDismissed() async {
    await _prefs.reload();
    return (_prefs.getStringList(kDismissed) ?? const []).toSet();
  }

  Future<void> saveDismissed(Set<String> keys) {
    // Solo se guardan las de los últimos días para no crecer sin límite.
    final cutoff = DateTime.now().subtract(const Duration(days: 2));
    final keep = keys.where((k) => DateTime.tryParse(k)?.isAfter(cutoff) ?? false).toList();
    return _prefs.setStringList(kDismissed, keep);
  }

  /// Borra los datos de esta cuenta (sin namespace, todo el almacenamiento).
  Future<void> clearAll() async {
    if (namespace.isEmpty) {
      await _prefs.clear();
      return;
    }
    for (final key in _prefs.getKeys().where((k) => k.startsWith('u:$namespace:')).toList()) {
      await _prefs.remove(key);
    }
  }

  List<Map<String, dynamic>> _readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }
}
