/// Cuenta de un estudiante. El nickname es el nombre que aparece en el
/// ranking. La contraseña nunca se guarda: solo su hash (ver
/// `PasswordHasher`), que vive en el repositorio y no en este modelo.
class Account {
  const Account({required this.id, required this.nickname, required this.email, required this.createdAt});

  final String id;
  final String nickname;
  final String email;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'email': email,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    nickname: json['nickname'] as String,
    email: json['email'] as String,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Reglas de los campos del registro (las mismas sirven para la base de datos).
class AccountRules {
  static final _nickname = RegExp(r'^[A-Za-z0-9_.]{3,15}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? nickname(String v) {
    final s = v.trim();
    if (s.isEmpty) return 'Escribe un nickname';
    if (!_nickname.hasMatch(s)) return 'De 3 a 15 letras, números, punto o guion bajo (sin espacios)';
    return null;
  }

  static String? email(String v) {
    final s = v.trim();
    if (s.isEmpty) return 'Escribe tu correo';
    if (!_email.hasMatch(s)) return 'Revisa el correo (ejemplo: ana@ucundinamarca.edu.co)';
    return null;
  }

  static String? password(String v) {
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Usa al menos una letra y un número';
    }
    return null;
  }
}
