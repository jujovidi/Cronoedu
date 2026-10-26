import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import 'leaderboard_repository.dart';
import 'password_hasher.dart';
import 'storage_service.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lo que la app necesita de las cuentas. Hoy lo cumple
/// [LocalAuthRepository]; al pasar a base de datos basta con otra
/// implementación (por ejemplo, contra una API) sin tocar las pantallas.
abstract class AuthRepository {
  /// Cuenta con sesión abierta al iniciar la app (o null).
  Account? get currentAccount;

  Future<Account> register({required String nickname, required String email, required String password});

  /// [user] puede ser el correo o el nickname.
  Future<Account> login({required String user, required String password});

  Future<void> logout();

  Future<bool> nicknameAvailable(String nickname);

  /// Borra la cuenta, sus datos y su puesto en el ranking.
  Future<void> deleteAccount(String accountId);
}

/// Cuentas guardadas en el celular (shared_preferences). La contraseña se
/// guarda solo como hash PBKDF2.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._prefs, {PasswordHasher hasher = const PasswordHasher()}) : _hasher = hasher;

  static const _kAccounts = 'accounts';
  static const _kSession = 'session';

  final SharedPreferences _prefs;
  final PasswordHasher _hasher;

  List<Map<String, dynamic>> _readAll() {
    final raw = _prefs.getString(_kAccounts);
    return raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _writeAll(List<Map<String, dynamic>> all) => _prefs.setString(_kAccounts, jsonEncode(all));

  @override
  Account? get currentAccount {
    final id = _prefs.getString(_kSession);
    if (id == null) return null;
    final row = _readAll().where((a) => a['id'] == id).firstOrNull;
    return row == null ? null : Account.fromJson(row);
  }

  @override
  Future<bool> nicknameAvailable(String nickname) async {
    final n = nickname.trim().toLowerCase();
    if (LocalLeaderboardRepository.demoNicknames.contains(n)) return false;
    return !_readAll().any((a) => (a['nickname'] as String).toLowerCase() == n);
  }

  @override
  Future<Account> register({required String nickname, required String email, required String password}) async {
    final error = AccountRules.nickname(nickname) ?? AccountRules.email(email) ?? AccountRules.password(password);
    if (error != null) throw AuthException(error);
    final all = _readAll();
    if (!await nicknameAvailable(nickname)) throw const AuthException('Ese nickname ya está en uso. Prueba con otro.');
    final mail = email.trim().toLowerCase();
    if (all.any((a) => a['email'] == mail)) throw const AuthException('Ya existe una cuenta con ese correo.');

    final account = Account(id: const Uuid().v4(), nickname: nickname.trim(), email: mail, createdAt: DateTime.now());
    // La primera cuenta del celular se queda con los datos que ya había
    // (tareas, horario y avatar de antes de existir el inicio de sesión).
    if (all.isEmpty) await StorageService.adoptLegacyData(_prefs, account.id);
    all.add({...account.toJson(), 'passwordHash': _hasher.hash(password)});
    await _writeAll(all);
    await _prefs.setString(_kSession, account.id);
    return account;
  }

  @override
  Future<Account> login({required String user, required String password}) async {
    final u = user.trim().toLowerCase();
    final row = _readAll().where((a) => a['email'] == u || (a['nickname'] as String).toLowerCase() == u).firstOrNull;
    if (row == null || !_hasher.verify(password, row['passwordHash'] as String)) {
      throw const AuthException('Correo, nickname o contraseña incorrectos.');
    }
    await _prefs.setString(_kSession, row['id'] as String);
    return Account.fromJson(row);
  }

  @override
  Future<void> logout() => _prefs.remove(_kSession);

  @override
  Future<void> deleteAccount(String accountId) async {
    await _writeAll(_readAll()..removeWhere((a) => a['id'] == accountId));
    await StorageService(_prefs, namespace: accountId).clearAll();
    await LocalLeaderboardRepository(_prefs).remove(accountId);
    if (_prefs.getString(_kSession) == accountId) await _prefs.remove(_kSession);
  }
}
