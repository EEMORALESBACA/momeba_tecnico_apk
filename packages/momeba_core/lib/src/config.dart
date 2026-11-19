import 'dart:io';

/// Datos fijos del servidor de Grupo Momeba (HostGator).
class MomebaConfig {
  MomebaConfig._();

  /// Carpeta donde viven servicio.html y api.php (todo el servidor).
  static const servidor = 'https://grupomomeba.com/servicio';

  static const api = '$servidor/api.php';
  /// HostGator (ModSecurity) responde 406 a las peticiones con el agente
  /// "Dart/x (dart:io)" o sin Accept; por eso la app se presenta como navegador.
  static const userAgent = 'Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile GrupoMomebaTecnico/1.0';
  /// Encabezados que manda Chrome al panel; con ellos HostGator no bloquea la app.
  static void encabezadosNavegador(HttpHeaders h) {
    h.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
    h.set(HttpHeaders.acceptLanguageHeader, 'es-MX,es;q=0.9');
    h.set('Origin', 'https://grupomomeba.com');
    h.set(HttpHeaders.refererHeader, '$servidor/servicio.html');
  }
  static const seguridadPhp = '$api?m=seguridad';
  static const archivosPhp = '$api?m=archivos';

  /// Página pública que abre el QR del técnico (se le agrega el uid al final).
  static const verificarTecnico = '$servidor/servicio.html?tecnico=';

  /// Página donde el cliente sigue su orden, escribe y llama.
  static String ligaSeguimiento(String clave) => '$servidor/servicio.html?o=${Uri.encodeQueryComponent(clave)}';

  /// Sesión sin actividad antes de pedir de nuevo el código de Google Authenticator.
  static const inactividad = Duration(hours: 2);
}
