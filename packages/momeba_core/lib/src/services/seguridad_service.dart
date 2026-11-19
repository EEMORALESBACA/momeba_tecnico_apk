import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';

class ErrorSeguridad implements Exception {
  ErrorSeguridad(this.mensaje, {this.caducada = false, this.sinConexion = false});
  final String mensaje;
  final bool caducada;
  final bool sinConexion;
  @override
  String toString() => mensaje;
}

/// Estado de la verificación en dos pasos del usuario.
class EstadoSeguridad {
  const EstadoSeguridad({required this.inscrito, required this.sesion, this.respaldoRestante = 0});
  final bool inscrito;
  final bool sesion;
  final int respaldoRestante;
}

/// Alta de Google Authenticator para este usuario.
class AltaAutenticador {
  const AltaAutenticador({required this.secreto, required this.uri});
  final String secreto;
  final String uri; // otpauth://totp/…
}

/// Habla con api.php?m=seguridad (HostGator): el código de Google Authenticator se
/// valida en el servidor y abre una sesión de 2 horas que exigen las reglas
/// de Firestore. Es el mismo mecanismo que usa el panel web.
class SeguridadService {
  SeguridadService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> _llamar(String accion, [Map<String, dynamic>? extra]) async {
    final user = _auth.currentUser;
    if (user == null) throw ErrorSeguridad('No hay sesión iniciada.');
    final token = await user.getIdToken();
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = MomebaConfig.userAgent;
    try {
      final req = await cliente.postUrl(Uri.parse(MomebaConfig.seguridadPhp));
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.write(jsonEncode({'idToken': token, 'accion': accion, ...?extra}));
      final res = await req.close().timeout(const Duration(seconds: 25));
      final cuerpo = await res.transform(utf8.decoder).join();
      Map<String, dynamic> j;
      try {
        j = jsonDecode(cuerpo) as Map<String, dynamic>;
      } catch (_) {
        throw ErrorSeguridad('El verificador de seguridad respondió algo inesperado (${res.statusCode}).');
      }
      if (j['ok'] != true) {
        throw ErrorSeguridad((j['error'] as String?) ?? 'Error de seguridad.', caducada: j['caducada'] == true);
      }
      return j;
    } on ErrorSeguridad {
      rethrow;
    } catch (_) {
      throw ErrorSeguridad('Sin conexión con el servidor de Grupo Momeba. Revisa tus datos o WiFi.', sinConexion: true);
    } finally {
      cliente.close();
    }
  }

  Future<EstadoSeguridad> estado() async {
    final j = await _llamar('estado');
    return EstadoSeguridad(
      inscrito: j['inscrito'] == true,
      sesion: j['sesion'] == true,
      respaldoRestante: (j['respaldoRestante'] as num?)?.toInt() ?? 0,
    );
  }

  Future<AltaAutenticador> alta() async {
    final j = await _llamar('alta');
    return AltaAutenticador(secreto: j['secreto'] as String, uri: j['uri'] as String);
  }

  /// Confirma el primer código; regresa los códigos de respaldo.
  Future<List<String>> confirmar(String codigo) async {
    final j = await _llamar('confirmar', {'codigo': codigo});
    return (j['respaldo'] as List).map((e) => e.toString()).toList();
  }

  /// Verifica un código de la app o de respaldo. Regresa cuántos respaldos quedan
  /// si se usó uno; null si fue un código de la app.
  Future<int?> verificar(String codigo) async {
    final j = await _llamar('verificar', {'codigo': codigo});
    return (j['respaldoRestante'] as num?)?.toInt();
  }

  Future<void> renovar() => _llamar('renovar');

  Future<void> cerrar() async {
    try {
      await _llamar('cerrar').timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
