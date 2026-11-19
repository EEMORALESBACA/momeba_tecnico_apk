import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momeba_core/momeba_core.dart';

import '../services/rastreo_respaldo.dart';
import '../services/ubicacion_global.dart';

final authServiceProvider = Provider((ref) => AuthService());
final tecnicoRepositoryProvider = Provider((ref) => TecnicoRepository());
final servicioRepositoryProvider = Provider((ref) => ServicioRepository());
final storageServiceProvider = Provider((ref) => StorageService());
final almacenRepositoryProvider = Provider((ref) => AlmacenRepository());
final descargasRepositoryProvider = Provider((ref) => DescargasRepository());
final seguridadServiceProvider = Provider((ref) => SeguridadService());

/// Sesión de Firebase Auth (null si no hay usuario logueado).
final sesionProvider = StreamProvider((ref) => ref.watch(authServiceProvider).cambiosDeSesion);

/// Documento del técnico logueado (`usuarios/{uid}`). Se puede leer aunque
/// todavía no haya escrito su código de Google Authenticator.
final tecnicoActualProvider = StreamProvider<Tecnico?>((ref) {
  final uid = ref.watch(sesionProvider.select((s) => s.value?.uid));
  if (uid == null) return Stream.value(null);
  return ref.watch(tecnicoRepositoryProvider).observar(uid);
});

/* ================= Verificación en dos pasos ================= */

enum FaseSeguridad { revisando, alta, respaldo, codigo, lista, error }

class EstadoGate {
  const EstadoGate(this.fase, {this.alta, this.respaldo = const [], this.mensaje});
  final FaseSeguridad fase;
  final AltaAutenticador? alta;
  final List<String> respaldo;

  /// Error (fase error) o aviso que se muestra en la pantalla del código.
  final String? mensaje;
}

/// Controla la puerta de seguridad: alta de Google Authenticator, código al
/// entrar y de nuevo tras 2 horas sin actividad. La sesión la valida el
/// servidor (api.php?m=seguridad) y la exigen las reglas de Firestore.
class SeguridadNotifier extends StateNotifier<EstadoGate> {
  SeguridadNotifier(this._svc, {required bool conUsuario})
      : super(const EstadoGate(FaseSeguridad.revisando)) {
    if (conUsuario) revisar();
  }

  final SeguridadService _svc;
  DateTime _ultimaActividad = DateTime.now();
  DateTime _ultimaRenovacion = DateTime.now();
  bool _renovando = false;

  static const _renovarCada = Duration(minutes: 10);
  static const avisoInactividad =
      'Por seguridad, después de 2 horas sin actividad vuelve a escribir tu código de Google Authenticator.';

  bool get lista => state.fase == FaseSeguridad.lista;

  Future<void> revisar() async {
    state = const EstadoGate(FaseSeguridad.revisando);
    try {
      final e = await _svc.estado();
      if (!mounted) return;
      if (e.sesion) {
        _entrar();
      } else if (!e.inscrito) {
        final alta = await _svc.alta();
        if (mounted) state = EstadoGate(FaseSeguridad.alta, alta: alta);
      } else {
        state = const EstadoGate(FaseSeguridad.codigo);
      }
    } on ErrorSeguridad catch (e) {
      if (mounted) state = EstadoGate(FaseSeguridad.error, mensaje: e.mensaje);
    }
  }

  void _entrar() {
    _ultimaActividad = DateTime.now();
    _ultimaRenovacion = DateTime.now();
    state = const EstadoGate(FaseSeguridad.lista);
  }

  /// Primer código tras escanear el QR. Regresa un mensaje de error o null.
  Future<String?> confirmarAlta(String codigo) async {
    try {
      final r = await _svc.confirmar(codigo);
      state = EstadoGate(FaseSeguridad.respaldo, respaldo: r);
      return null;
    } on ErrorSeguridad catch (e) {
      return e.mensaje;
    }
  }

  void terminarRespaldo() => _entrar();

  /// Código de la app o de respaldo. Regresa (error, respaldosRestantes).
  Future<(String?, int?)> verificar(String codigo) async {
    try {
      final restantes = await _svc.verificar(codigo);
      _entrar();
      return (null, restantes);
    } on ErrorSeguridad catch (e) {
      return (e.mensaje, null);
    }
  }

  /// Cada toque en pantalla cuenta como actividad y, cada 10 min, renueva la
  /// sesión del servidor por 2 horas más.
  void actividad() {
    if (!lista) return;
    if (revisarInactividad()) return;
    _ultimaActividad = DateTime.now();
    if (!_renovando && DateTime.now().difference(_ultimaRenovacion) > _renovarCada) {
      _renovando = true;
      _ultimaRenovacion = DateTime.now();
      _svc.renovar().catchError((e) {
        if (e is ErrorSeguridad && e.caducada) sesionCaducada();
      }).whenComplete(() => _renovando = false);
    }
  }

  /// Si pasaron 2 horas sin actividad, pide de nuevo el código.
  bool revisarInactividad() {
    if (lista && DateTime.now().difference(_ultimaActividad) > MomebaConfig.inactividad) {
      _svc.cerrar();
      state = const EstadoGate(FaseSeguridad.codigo, mensaje: avisoInactividad);
      return true;
    }
    return false;
  }

  /// Al volver a la app: confirma con el servidor que la sesión siga viva.
  Future<void> alVolver() async {
    if (!lista || revisarInactividad()) return;
    try {
      final e = await _svc.estado();
      if (!e.sesion) sesionCaducada();
    } catch (_) {}
  }

  void sesionCaducada() {
    if (mounted && lista) state = const EstadoGate(FaseSeguridad.codigo, mensaje: avisoInactividad);
  }
}

final seguridadProvider = StateNotifierProvider<SeguridadNotifier, EstadoGate>((ref) {
  final uid = ref.watch(sesionProvider.select((s) => s.value?.uid));
  return SeguridadNotifier(ref.watch(seguridadServiceProvider), conUsuario: uid != null);
});

final _sesionLista = Provider<bool>((ref) => ref.watch(seguridadProvider.select((s) => s.fase == FaseSeguridad.lista)));

/// Convierte un "permiso denegado" de Firestore en "pide de nuevo el código".
Stream<T> _vigilarSesion<T>(Ref ref, Stream<T> s) => s.handleError((Object e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        Future.microtask(() => ref.read(seguridadProvider.notifier).sesionCaducada());
      }
      throw e;
    });

/// Servicios asignados al técnico logueado, en cualquier estado activo
/// (asignado/aceptado/en camino/en sitio). Solo con la sesión verificada.
final serviciosAsignadosProvider = StreamProvider<List<ServicioAsignado>>((ref) {
  final tecnico = ref.watch(tecnicoActualProvider).value;
  if (tecnico == null || !ref.watch(_sesionLista)) return const Stream.empty();
  return _vigilarSesion(ref, ref.watch(servicioRepositoryProvider).observarPorTecnico(tecnico.uid));
});

final historialServiciosProvider = StreamProvider<List<ServicioAsignado>>((ref) {
  final tecnico = ref.watch(tecnicoActualProvider).value;
  if (tecnico == null || !ref.watch(_sesionLista)) return const Stream.empty();
  return _vigilarSesion(ref, ref.watch(servicioRepositoryProvider).observarHistorial(tecnico.uid));
});

final descargasProvider = StreamProvider<List<Descarga>>((ref) {
  if (!ref.watch(_sesionLista)) return const Stream.empty();
  return _vigilarSesion(ref, ref.watch(descargasRepositoryProvider).observar());
});

/// Cierra todo: sesión del servidor, ubicación y Firebase.
Future<void> cerrarSesionCompleta(WidgetRef ref) async {
  await ref.read(seguridadServiceProvider).cerrar();
  await UbicacionGlobal.detener();
  await RastreoRespaldo.cancelar();
  await ref.read(authServiceProvider).cerrarSesion();
}
