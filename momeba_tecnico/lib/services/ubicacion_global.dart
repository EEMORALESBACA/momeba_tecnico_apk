import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:momeba_core/momeba_core.dart';

/// Publica la ubicación del técnico a Firestore (ubicaciones/{uid})
/// de forma CONTINUA, incluso con la app minimizada o la pantalla apagada.
///
/// Usa un servicio en primer plano de Android (vía geolocator): mientras el
/// técnico tenga sesión iniciada, Android mantiene vivo el rastreo y muestra
/// una notificación fija "Momeba Técnico en servicio" que le indica que su
/// ubicación se está compartiendo con el centro de operaciones.
class UbicacionGlobal {
  UbicacionGlobal._();

  static StreamSubscription<Position>? _sub;
  static String? _uidActivo;

  /// Servicios "En camino" con domicilio ubicado: id → (lat, lng).
  /// Al llegar a menos de [radioLlegada] metros, la orden pasa sola a "En sitio"
  /// aunque la app esté minimizada o la pantalla apagada.
  static final Map<String, ({double lat, double lng})> destinos = {};
  static const double radioLlegada = 100;
  static final Set<String> _marcando = {};

  /// Lo llama la app cada vez que cambian los servicios del técnico.
  static void actualizarDestinos(List<ServicioAsignado> servicios) {
    destinos
      ..clear()
      ..addEntries(servicios
          .where((s) => s.estadoAsignacion == EstadoAsignacion.enCamino && s.clienteLat != null && s.clienteLng != null)
          .map((s) => MapEntry(s.id, (lat: s.clienteLat!, lng: s.clienteLng!))));
  }

  static void _revisarLlegadas(Position p) {
    for (final e in destinos.entries.toList()) {
      if (_marcando.contains(e.key)) continue;
      final d = distanciaMetros(p.latitude, p.longitude, e.value.lat, e.value.lng);
      if (d <= radioLlegada) {
        _marcando.add(e.key);
        destinos.remove(e.key);
        ServicioRepository()
            .marcarEnSitio(e.key, automatico: true, distancia: d)
            .whenComplete(() => _marcando.remove(e.key))
            .catchError((_) {});
      }
    }
  }

  static Future<void> iniciar(String uid, TecnicoRepository repo, {String? nombre}) async {
    if (_uidActivo == uid && _sub != null) return; // ya publicando
    await detener();
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso != LocationPermission.always &&
        permiso != LocationPermission.whileInUse) {
      return;
    }
    _uidActivo = uid;

    // Primera posición inmediata para aparecer en el mapa sin esperar.
    try {
      final p = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      await repo.actualizarUbicacion(uid, p.latitude, p.longitude, nombre: nombre);
    } catch (_) {}

    // Stream con SERVICIO EN PRIMER PLANO: sigue publicando en background.
    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30, // publica al moverse ~30 m (cuida batería y cuota)
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Momeba Técnico en servicio',
          notificationText:
              'Compartiendo tu ubicación con el centro de operaciones de Grupo Momeba.',
          notificationIcon:
              AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
    ).listen((p) {
      repo.actualizarUbicacion(uid, p.latitude, p.longitude, nombre: nombre).catchError((_) {});
      _revisarLlegadas(p);
    });
  }

  static Future<void> detener() async {
    await _sub?.cancel();
    _sub = null;
    _uidActivo = null;
  }
}
