import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/account.dart';
import '../models/avatar.dart';
import 'auth_repository.dart';
import 'bellotas_repository.dart';
import 'leaderboard_repository.dart';

// Cuentas, ranking y bellotas contra la base de Supabase
// (supabase/migrations/0001_esquema.sql). Los mensajes de error de las
// funciones de la base ya vienen en español y se muestran tal cual.

const _sinConexion = 'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.';

/// Cuentas con Supabase Auth. La contraseña la guarda y verifica Supabase.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final sb.SupabaseClient _client;
  sb.GoTrueClient get _auth => _client.auth;

  static Account? _toAccount(sb.User? u) => u == null
      ? null
      : Account(
          id: u.id,
          nickname: (u.userMetadata?['nickname'] as String?) ?? '',
          email: u.email ?? '',
          createdAt: DateTime.tryParse(u.createdAt) ?? DateTime.now(),
        );

  /// Supabase guarda la sesión en el celular, así que se conoce al abrir la app.
  @override
  Account? get currentAccount => _toAccount(_auth.currentUser);

  @override
  Future<bool> nicknameAvailable(String nickname) =>
      _call(() async => await _client.rpc('nickname_disponible', params: {'p_nickname': nickname.trim()}) as bool);

  @override
  Future<Account> register({required String nickname, required String email, required String password}) async {
    final error = AccountRules.nickname(nickname) ?? AccountRules.email(email) ?? AccountRules.password(password);
    if (error != null) throw AuthException(error);
    if (!await nicknameAvailable(nickname)) throw const AuthException('Ese nickname ya está en uso. Prueba con otro.');
    final res = await _call(
      () => _auth.signUp(email: email.trim().toLowerCase(), password: password, data: {'nickname': nickname.trim()}),
    );
    // Si el proyecto pide confirmar el correo, no hay sesión hasta confirmarlo.
    if (res.session == null) {
      throw const AuthException('Te enviamos un correo para confirmar la cuenta. Ábrelo y luego inicia sesión.');
    }
    return _toAccount(res.user)!;
  }

  @override
  Future<Account> login({required String user, required String password}) async {
    final u = user.trim().toLowerCase();
    // Buscar el correo de un nickname expondría los correos de todos.
    if (!u.contains('@')) throw const AuthException('Inicia sesión con tu correo; el nickname es el de tu ranking.');
    final res = await _call(() => _auth.signInWithPassword(email: u, password: password));
    return _toAccount(res.user)!;
  }

  @override
  Future<void> logout() => _call(() => _auth.signOut());

  @override
  Future<void> deleteAccount(String accountId) async {
    await _call(() => _client.rpc('borrar_mi_cuenta'));
    // La cuenta ya no existe en el servidor: solo se olvida la sesión local.
    await _auth.signOut(scope: sb.SignOutScope.local);
  }

  static Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on sb.AuthRetryableFetchException {
      throw const AuthException(_sinConexion);
    } on sb.AuthException catch (e) {
      throw AuthException(switch (e.code) {
        'invalid_credentials' => 'Correo o contraseña incorrectos.',
        'email_not_confirmed' => 'Confirma tu correo (revisa tu bandeja) y vuelve a intentar.',
        'user_already_exists' || 'email_exists' => 'Ya existe una cuenta con ese correo.',
        'weak_password' => 'La contraseña es muy débil. Usa letras y números (mínimo 8).',
        'over_email_send_rate_limit' || 'over_request_rate_limit' => 'Demasiados intentos. Espera un momento.',
        _ => e.message,
      });
    } on sb.PostgrestException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      debugPrint('Supabase: $e');
      throw const AuthException(_sinConexion);
    }
  }
}

/// Ranking leído de las vistas ranking_semanal y ranking_total. Los puntos
/// los calcula la base con las bellotas ganadas, así que no hay nada que subir.
class SupabaseLeaderboardRepository implements LeaderboardRepository {
  SupabaseLeaderboardRepository(this._client, {this.limit = 100});

  final sb.SupabaseClient _client;
  final int limit;

  @override
  Future<void> publish(LeaderboardEntry entry) async {}

  /// La base lo saca del ranking al borrar la cuenta (borrar_mi_cuenta).
  @override
  Future<void> remove(String accountId) async {}

  @override
  Future<List<LeaderboardEntry>> fetch(LeaderboardPeriod period) async {
    final view = period == LeaderboardPeriod.semana ? 'ranking_semanal' : 'ranking_total';
    final rows = await _client
        .from(view)
        .select('usuario_id, nickname, avatar, puntos')
        .order('puntos', ascending: false)
        .limit(limit);
    final week = currentWeekKey();
    final list = [
      for (final r in rows)
        LeaderboardEntry(
          accountId: r['usuario_id'] as String,
          nickname: r['nickname'] as String,
          avatar: AvatarLook.fromJson(r['avatar'] as Map<String, dynamic>?),
          points: r['puntos'] as int,
          weekPoints: r['puntos'] as int,
          weekKey: week,
        ),
    ];
    list.sort((a, b) {
      final d = b.points.compareTo(a.points);
      return d != 0 ? d : a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase());
    });
    return list;
  }
}

/// Bellotas con las funciones de la base (ganar_enfoque, ganar_ciclo,
/// ganar_tarea, comprar_objeto y mi_estado).
class SupabaseBellotasRepository implements BellotasRepository {
  SupabaseBellotasRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<ServerProfile?> load() async {
    final r = await _client.rpc('mi_estado');
    return r == null ? null : ServerProfile.fromJson(Map<String, dynamic>.from(r as Map));
  }

  @override
  Future<int> earnFocus(int minutes) async =>
      await _client.rpc('ganar_enfoque', params: {'p_minutos': minutes}) as int;

  @override
  Future<(int, int)> earnCycle() async {
    final r = Map<String, dynamic>.from(await _client.rpc('ganar_ciclo') as Map);
    return (r['bellotas'] as int, r['bono_racha'] as int);
  }

  @override
  Future<int> earnTask(String taskId, {required bool onTime}) async =>
      await _client.rpc('ganar_tarea', params: {'p_tarea_id': taskId, 'p_a_tiempo': onTime}) as int;

  @override
  Future<int> buy(String itemId) async => await _client.rpc('comprar_objeto', params: {'p_objeto': itemId}) as int;

  @override
  Future<void> saveProfile({
    required String name,
    required String career,
    required int semester,
    required AvatarLook avatar,
  }) => _client
      .from('perfiles')
      .update({'nombre': name, 'carrera': career, 'semestre': semester, 'avatar': avatar.toJson()})
      .eq('id', _client.auth.currentUser!.id);
}
