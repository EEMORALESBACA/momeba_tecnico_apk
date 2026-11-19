import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';

/// Error al subir un archivo; [caducada] indica que hay que volver a pedir el código.
class ErrorSubida implements Exception {
  ErrorSubida(this.mensaje, {this.caducada = false});
  final String mensaje;
  final bool caducada;
  @override
  String toString() => mensaje;
}

/// Sube evidencia (fotos, firma, video, PDF) al servidor de Grupo Momeba en
/// HostGator (api.php?m=archivos), por partes de 4 MB, y regresa la liga pública
/// del archivo para guardarla en Firestore.
class StorageService {
  StorageService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  static const _parte = 4 * 1024 * 1024;

  Future<String> subirFotoTecnico(String uid, String nombreArchivo, Uint8List bytes) =>
      subir('tecnicos/$uid', nombreArchivo, bytes, 'image/jpeg');

  Future<String> subirFotoServicio(String servicioId, String nombreArchivo, Uint8List bytes) =>
      subir('servicios/$servicioId', nombreArchivo, bytes, 'image/jpeg');

  Future<String> subirVideoFalla(String servicioId, Uint8List bytes) =>
      subir('servicios/$servicioId', 'video_falla.mp4', bytes, 'video/mp4');

  Future<String> subirFirma(String servicioId, Uint8List bytes) =>
      subir('servicios/$servicioId', 'firma.png', bytes, 'image/png');

  Future<String> subirPdf(String servicioId, Uint8List bytes) =>
      subir('servicios/$servicioId', 'hoja_servicio.pdf', bytes, 'application/pdf');

  static String _idSubida() {
    final r = Random.secure();
    return List.generate(20, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<String> subir(String carpeta, String nombre, Uint8List bytes, String tipo,
      {void Function(double avance)? onAvance}) async {
    final user = _auth.currentUser;
    if (user == null) throw ErrorSubida('No hay sesión iniciada.');
    final id = _idSubida();
    final total = bytes.isEmpty ? 1 : (bytes.length / _parte).ceil();
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..userAgent = MomebaConfig.userAgent;
    try {
      String? url;
      for (var i = 0; i < total; i++) {
        final ini = i * _parte;
        final fin = min(ini + _parte, bytes.length);
        final token = await user.getIdToken();
        final uri = Uri.parse(MomebaConfig.archivosPhp).replace(queryParameters: {
          'm': 'archivos',
          'accion': 'parte',
          'id': id,
          'i': '$i',
          'n': '$total',
          'nombre': nombre,
          'carpeta': carpeta,
        });
        Map<String, dynamic> j = const {};
        var intentos = 0;
        while (true) {
          try {
            final req = await cliente.postUrl(uri);
            req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
            req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
            req.headers.contentType = ContentType('application', 'octet-stream');
            req.add(bytes.sublist(ini, fin));
            final res = await req.close().timeout(const Duration(minutes: 3));
            final cuerpo = await res.transform(utf8.decoder).join();
            try {
              j = jsonDecode(cuerpo) as Map<String, dynamic>;
            } catch (_) {
              j = {'ok': false, 'error': 'Respuesta inesperada del servidor (${res.statusCode}).'};
            }
            break;
          } on IOException {
            if (++intentos >= 3) throw ErrorSubida('Sin conexión al subir el archivo. Revisa tus datos o WiFi.');
            await Future.delayed(Duration(seconds: 2 * intentos));
          }
        }
        if (j['ok'] != true) {
          throw ErrorSubida((j['error'] as String?) ?? 'No se pudo subir el archivo.', caducada: j['caducada'] == true);
        }
        onAvance?.call((i + 1) / total);
        url = j['url'] as String?;
      }
      if (url == null) throw ErrorSubida('El servidor no regresó la liga del archivo.');
      return url;
    } finally {
      cliente.close();
    }
  }
}
