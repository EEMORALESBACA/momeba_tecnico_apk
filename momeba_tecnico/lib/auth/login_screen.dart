import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../tema.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  bool _cargando = false;
  bool _ver = false;
  String? _error;
  String? _aviso;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  String _mensaje(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Correo o contraseña incorrectos.',
        'invalid-email' => 'El correo no es válido.',
        'too-many-requests' => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
        'network-request-failed' => 'Sin conexión a internet. Revisa tus datos o WiFi.',
        'user-disabled' => 'Tu cuenta está deshabilitada.',
        _ => e.message ?? 'No se pudo iniciar sesión.',
      };

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
      _aviso = null;
    });
    try {
      await ref.read(authServiceProvider).iniciarSesion(_correoCtrl.text, _contrasenaCtrl.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mensaje(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvide() async {
    final c = _correoCtrl.text.trim();
    if (!c.contains('@')) {
      setState(() => _error = 'Escribe tu correo arriba y vuelve a tocar "¿Olvidaste tu contraseña?".');
      return;
    }
    try {
      await ref.read(authServiceProvider).recuperarContrasena(c);
      setState(() {
        _error = null;
        _aviso = 'Si el correo está registrado, te llegará un enlace para crear una nueva contraseña.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mensaje(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Momeba.fondo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE1E3EC)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoMomeba(),
                    const SizedBox(height: 26),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Acceso técnico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Momeba.indigo)),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contrasenaCtrl,
                      obscureText: !_ver,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                          icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _ver = !_ver),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                      onFieldSubmitted: (_) => _iniciarSesion(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                    ],
                    if (_aviso != null) ...[
                      const SizedBox(height: 12),
                      Text(_aviso!, style: const TextStyle(color: Color(0xFF1E7B4F))),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Momeba.turquesa,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _cargando ? null : _iniciarSesion,
                        child: _cargando
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    TextButton(
                      onPressed: _cargando ? null : _olvide,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                    const SizedBox(height: 4),
                    const Text('Tu cuenta la crea el Super Admin de Grupo Momeba.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Momeba.texto)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
