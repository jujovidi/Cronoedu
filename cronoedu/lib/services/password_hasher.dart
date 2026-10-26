import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash de contraseñas con PBKDF2-HMAC-SHA256 y sal aleatoria. Se guarda
/// como `pbkdf2$iteraciones$sal$hash` (base64), así el servidor podrá
/// verificar las mismas contraseñas cuando pasemos a base de datos.
class PasswordHasher {
  const PasswordHasher({this.iterations = 10000});

  final int iterations;

  String hash(String password) {
    final rnd = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rnd.nextInt(256)));
    final key = _pbkdf2(utf8.encode(password), salt, iterations);
    return 'pbkdf2\$$iterations\$${base64.encode(salt)}\$${base64.encode(key)}';
  }

  bool verify(String password, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null) return false;
    final key = _pbkdf2(utf8.encode(password), base64.decode(parts[2]), iterations);
    final expected = base64.decode(parts[3]);
    if (key.length != expected.length) return false;
    var diff = 0; // comparación en tiempo constante
    for (var i = 0; i < key.length; i++) {
      diff |= key[i] ^ expected[i];
    }
    return diff == 0;
  }

  static List<int> _pbkdf2(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = List<int>.of(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }
}
