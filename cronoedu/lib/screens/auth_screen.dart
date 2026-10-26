import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../services/auth_repository.dart';
import '../state/auth_controller.dart';
import '../widgets/mascot.dart';

/// Iniciar sesión o crear cuenta (nickname, correo y contraseña).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _nickname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_user, _nickname, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    try {
      if (_register) {
        await auth.register(nickname: _nickname.text, email: _email.text, password: _password.text);
      } else {
        await auth.login(user: _user.text, password: _password.text);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final busy = context.watch<AuthController>().busy;
    // Con servidor se entra con el correo (ver SupabaseAuthRepository.login).
    final cloud = context.read<AuthController>().cloud;
    final passwordToggle = IconButton(
      tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
      onPressed: () => setState(() => _showPassword = !_showPassword),
      icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Mascot(_register ? MascotPose.logro : MascotPose.escritorio, size: 140),
                  Text('CronoEdu', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  Text(
                    _register ? 'Crea tu cuenta para entrar al ranking' : '¡Qué bueno verte de nuevo!',
                    style: t.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Iniciar sesión')),
                      ButtonSegment(value: true, label: Text('Crear cuenta')),
                    ],
                    selected: {_register},
                    onSelectionChanged: (s) => setState(() {
                      _register = s.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _form,
                        child: Column(
                          children: [
                            if (_register) ...[
                              TextFormField(
                                controller: _nickname,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Nickname',
                                  prefixIcon: Icon(Icons.alternate_email_rounded),
                                  helperText: 'Así te verán en el ranking',
                                ),
                                validator: (v) => AccountRules.nickname(v ?? ''),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Correo',
                                  prefixIcon: Icon(Icons.mail_rounded),
                                ),
                                validator: (v) => AccountRules.email(v ?? ''),
                              ),
                            ] else
                              TextFormField(
                                controller: _user,
                                textInputAction: TextInputAction.next,
                                keyboardType: cloud ? TextInputType.emailAddress : null,
                                decoration: InputDecoration(
                                  labelText: cloud ? 'Correo' : 'Correo o nickname',
                                  prefixIcon: const Icon(Icons.person_rounded),
                                ),
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? (cloud ? 'Escribe tu correo' : 'Escribe tu correo o nickname')
                                    : null,
                              ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: !_showPassword,
                              textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                              onFieldSubmitted: _register ? null : (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_rounded),
                                suffixIcon: passwordToggle,
                                helperText: _register ? 'Mínimo 8 caracteres, con letras y números' : null,
                              ),
                              validator: (v) => _register
                                  ? AccountRules.password(v ?? '')
                                  : ((v ?? '').isEmpty ? 'Escribe tu contraseña' : null),
                            ),
                            if (_register) ...[
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirm,
                                obscureText: !_showPassword,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: const InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                                validator: (v) => v != _password.text ? 'Las contraseñas no coinciden' : null,
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: busy ? null : _submit,
                                child: busy
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.5),
                                      )
                                    : Text(_register ? 'CREAR CUENTA' : 'ENTRAR'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cloud
                        ? 'Tu cuenta, tus bellotas y tu puesto en el ranking se guardan en la nube.'
                        : 'Por ahora tu cuenta y tus datos se guardan solo en este celular.',
                    style: t.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
