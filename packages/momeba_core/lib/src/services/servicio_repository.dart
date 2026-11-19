import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/orden_servicio.dart';
import '../models/servicio_asignado.dart';

/// Acceso a la colección `servicios` de Grupo Momeba (la misma del panel web).
/// Cada cambio de la app deja huella en `historial`, igual que el panel.
class ServicioRepository {
  ServicioRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance,
        _col = (firestore ?? FirebaseFirestore.instance).collection('servicios');

  final FirebaseFirestore _db;
  final CollectionReference<Map<String, dynamic>> _col;

  static const _activos = {
    EstadoAsignacion.asignado,
    EstadoAsignacion.aceptado,
    EstadoAsignacion.enCamino,
    EstadoAsignacion.enSitio,
  };

  String get _ahora => DateTime.now().toIso8601String();

  String get _quien {
    final u = FirebaseAuth.instance.currentUser;
    return u?.displayName ?? u?.email ?? 'Técnico';
  }

  /// Nombre del técnico para el historial (se fija al iniciar sesión).
  static String nombreTecnico = '';

  Map<String, dynamic> _huella(String estado, {String? motivo, String? nota}) => {
        'historial': FieldValue.arrayUnion([
          {
            'estado': estado,
            'motivo': motivo,
            'fecha': _ahora,
            'por': nombreTecnico.isNotEmpty ? nombreTecnico : _quien,
            'nota': nota,
          }
        ]),
        'actualizado': _ahora,
      };

  List<ServicioAsignado> _mapear(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => ServicioAsignado.fromMap(d.id, d.data())).toList();

  int _porFecha(ServicioAsignado a, ServicioAsignado b) =>
      (a.fechaProgramada ?? a.fechaCreacion).compareTo(b.fechaProgramada ?? b.fechaCreacion);

  /// Servicios activos del técnico (asignado/aceptado/en camino/en sitio).
  /// Un solo filtro de igualdad: no requiere índice compuesto.
  Stream<List<ServicioAsignado>> observarPorTecnico(String technicianId) => _col
      .where('tecnicoId', isEqualTo: technicianId)
      .snapshots()
      .map((s) => _mapear(s).where((x) => _activos.contains(x.estadoAsignacion)).toList()..sort(_porFecha));

  /// TODOS los servicios del técnico (activos y cerrados) para productividad.
  Stream<List<ServicioAsignado>> observarHistorial(String technicianId) =>
      _col.where('tecnicoId', isEqualTo: technicianId).snapshots().map(_mapear);

  Stream<ServicioAsignado?> observarUno(String id) => _col.doc(id).snapshots().map(
        (doc) => doc.exists ? ServicioAsignado.fromMap(doc.id, doc.data()!) : null,
      );

  Future<void> aceptar(String id) => _col.doc(id).update({
        'estado': 'aceptado',
        'fechaAceptado': _ahora,
        ..._huella('aceptado', nota: 'Aceptado por el técnico'),
      });

  Future<void> marcarEnCamino(String id) => _col.doc(id).update({
        'estado': 'encamino',
        'fechaEnCamino': _ahora,
        ..._huella('encamino'),
      });

  /// Llegada al domicilio. [automatico]: la detectó el GPS (a [distancia] metros).
  Future<void> marcarEnSitio(String id, {bool automatico = false, double? distancia}) => _col.doc(id).update({
        'estado': 'ensitio',
        'fechaEnSitio': _ahora,
        if (distancia != null) 'distanciaLlegada': distancia.round(),
        if (automatico) 'ubicacionValidada': true,
        ..._huella('ensitio',
            nota: automatico ? 'Llegada detectada por GPS${distancia != null ? ' a ${distancia.round()} m' : ''}' : null),
      });

  /// Llegada marcada a mano lejos del domicilio (o sin GPS): queda la foto del lugar como evidencia.
  Future<void> marcarEnSitioManual(String id, {double? distancia, double? lat, double? lng, required String fotoUrl}) =>
      _col.doc(id).update({
        'estado': 'ensitio',
        'fechaEnSitio': _ahora,
        'llegadaManual': true,
        'fotoLugarUrl': fotoUrl,
        if (distancia != null) 'distanciaLlegada': distancia.round(),
        if (lat != null && lng != null) 'llegadaLat': lat,
        if (lat != null && lng != null) 'llegadaLng': lng,
        ..._huella('ensitio',
            nota: 'Llegada marcada a mano${distancia != null ? ' a ${distancia.round()} m del domicilio' : ' sin GPS'} · con foto del lugar'),
      });

  /// "Estoy llegando": pasa la orden a En camino y guarda la hora estimada que ve el cliente.
  Future<void> avisarLlegando(String id, int minutos) {
    final ahora = DateTime.now();
    final llega = ahora.add(Duration(minutes: minutos));
    final hh = '${llega.hour.toString().padLeft(2, '0')}:${llega.minute.toString().padLeft(2, '0')}';
    return _col.doc(id).update({
      'estado': 'encamino',
      'fechaEnCamino': _ahora,
      'avisoLlegando': ahora.toUtc().toIso8601String(),
      'llegadaEstimada': llega.toUtc().toIso8601String(),
      ..._huella('encamino', nota: 'Estoy llegando · aprox. a las $hh'),
    });
  }

  Future<void> actualizarVideoFalla(String id, String videoUrl) =>
      _col.doc(id).update({'videoFallaUrl': videoUrl, 'actualizado': _ahora});

  /// Motivo de pendiente de la app → catálogo del panel web.
  static String _motivoPanel(String? m) {
    final t = (m ?? '').toLowerCase();
    if (t.contains('refacc')) return 'refaccion';
    if (t.contains('software')) return 'software';
    if (t.contains('ausente')) return 'ausente';
    if (t.contains('presupuesto')) return 'presupuesto';
    return 'otro';
  }

  Future<void> cerrar(
    String id, {
    required EstadoServicio estadoFinal,
    String? pdfUrl,
    String? motivoPendiente,
    String? motivoCancelacion,
    List<String> refaccionesFaltantes = const [],
    List<String> refaccionesUsadas = const [],
    String? fotoEquipoUrl,
    String? fotoPlacaUrl,
    String? fotoFallaUrl,
    String? fotoTicketCompraUrl,
    double? montoCobrado,
    String? metodoPago,
    String? modelo,
    String? numeroSerie,
  }) {
    final estado = estadoFinal.name; // completado | pendiente | cancelado
    final motivo = estadoFinal == EstadoServicio.pendiente ? _motivoPanel(motivoPendiente) : null;
    final notas = <String>[
      if (refaccionesUsadas.isNotEmpty) 'Refacciones usadas: ${refaccionesUsadas.join(', ')}',
      if (refaccionesFaltantes.isNotEmpty) 'Faltan: ${refaccionesFaltantes.join(', ')}',
      if (motivoCancelacion != null && motivoCancelacion.trim().isNotEmpty) 'Motivo: ${motivoCancelacion.trim()}',
      if (montoCobrado != null) 'Cobro: \$${montoCobrado.toStringAsFixed(0)}${metodoPago != null ? ' · $metodoPago' : ''}',
    ];
    return _col.doc(id).update({
      'estado': estado,
      'motivo': motivo,
      'pdfUrl': pdfUrl,
      'motivoPendiente': motivoPendiente,
      'refaccionesFaltantes': refaccionesFaltantes,
      'refaccionesUsadas': refaccionesUsadas,
      if (fotoEquipoUrl != null) 'fotoEquipoUrl': fotoEquipoUrl,
      if (fotoPlacaUrl != null) 'fotoPlacaUrl': fotoPlacaUrl,
      if (fotoFallaUrl != null) 'fotoFallaUrl': fotoFallaUrl,
      if (fotoTicketCompraUrl != null) 'fotoTicketCompraUrl': fotoTicketCompraUrl,
      if (montoCobrado != null) 'monto': montoCobrado.round(),
      if (metodoPago != null) 'metodoPago': metodoPago,
      if (modelo != null && modelo.trim().isNotEmpty) 'modelo': modelo.trim(),
      if (numeroSerie != null && numeroSerie.trim().isNotEmpty) 'serie': numeroSerie.trim(),
      'fechaCierre': _ahora,
      ..._huella(estado, motivo: motivo, nota: notas.isEmpty ? 'Cerrado desde la app' : notas.join(' · ')),
    });
  }

  /// Cuántas veces se completó ANTES un servicio con el mismo número de serie.
  /// Si las reglas no permiten la consulta, regresa 0 sin detener el cierre.
  Future<int> contarReincidencias(String numeroSerie, {String? excluirId}) async {
    if (numeroSerie.trim().isEmpty) return 0;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    final snap = await _col.where('tecnicoId', isEqualTo: uid).get();
    return snap.docs.where((d) {
      if (d.id == excluirId) return false;
      final data = d.data();
      return data['serie'] == numeroSerie.trim() && data['estado'] == 'completado';
    }).length;
  }

  /// Reprograma el servicio a otra fecha y lo regresa a "asignado".
  Future<void> reprogramar(String id, DateTime fecha, {String? technicianId}) {
    final f = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    return _col.doc(id).update({
      'fecha': f,
      'estado': 'asignado',
      'reagendado': _ahora,
      ..._huella('asignado', nota: 'Reagendado por el técnico para el $f'),
    });
  }

  /// Posición en vivo del técnico mientras va en camino (mapa del panel).
  Future<void> actualizarTracking(String servicioId, double lat, double lng) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Future.value();
    return _db.collection('ubicaciones').doc(uid).set({
      'lat': lat,
      'lng': lng,
      'actualizado': _ahora,
      'servicioId': servicioId,
      'nombre': nombreTecnico,
    }, SetOptions(merge: true));
  }
}
