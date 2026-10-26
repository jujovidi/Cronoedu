import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../services/auth_repository.dart';
import '../services/bellotas_repository.dart';
import '../services/leaderboard_repository.dart';

/// Sesión del usuario: quién entró y las acciones de cuenta.
class AuthController extends ChangeNotifier {
  AuthController(this.repository, this.leaderboard, {this.bellotas}) : _account = repository.currentAccount;

  final AuthRepository repository;
  final LeaderboardRepository leaderboard;

  /// Servidor de bellotas de la cuenta (null = solo en el celular).
  final BellotasRepository? bellotas;

  /// Cuentas en el servidor (Supabase) y no solo en el celular.
  bool get cloud => bellotas != null;
  Account? _account;
  bool _busy = false;

  Account? get account => _account;
  bool get isLoggedIn => _account != null;
  bool get busy => _busy;

  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> register({required String nickname, required String email, required String password}) =>
      _run(() async => _account = await repository.register(nickname: nickname, email: email, password: password));

  Future<void> login({required String user, required String password}) =>
      _run(() async => _account = await repository.login(user: user, password: password));

  Future<void> logout() async {
    await repository.logout();
    _account = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final a = _account;
    if (a == null) return;
    await repository.deleteAccount(a.id);
    _account = null;
    notifyListeners();
  }
}
