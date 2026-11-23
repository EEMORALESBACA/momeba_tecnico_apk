import '../config.dart';
import 'orden_servicio.dart';

/// Ciclo de vida de una asignación de servicio, previo (y durante) el cierre.
/// El resultado final del servicio (completado/pendiente/cancelado) se
/// guarda en [EstadoServicio], no aquí.
enum EstadoAsignacion {
  pendienteAsignacion,
  asignado,
  aceptado,
  enCamino,
  enSitio,
  cerrado,
}

extension EstadoAsignacionX on EstadoAsignacion {
  String get etiqueta {
    switch (this) {
      case EstadoAsignacion.pendienteAsignacion:
        return 'Pendiente de asignación';
      case EstadoAsignacion.asignado:
        return 'Asignado';
      case EstadoAsignacion.aceptado:
        return 'Aceptado';
      case EstadoAsignacion.enCamino:
        return 'En camino';
      case EstadoAsignacion.enSitio:
        return 'En sitio';
      case EstadoAsignacion.cerrado:
        return 'Cerrado';
    }
  }

  static EstadoAsignacion desdeTexto(String texto) => EstadoAsignacion.values
      .firstWhere((e) => e.name == texto, orElse: () => EstadoAsignacion.pendienteAsignacion);

  /// Valor del campo `estado` en Grupo Momeba (el mismo que usa el panel web).
  String get estadoMomeba => switch (this) {
        EstadoAsignacion.pendienteAsignacion => 'asignado',
        EstadoAsignacion.asignado => 'asignado',
        EstadoAsignacion.aceptado => 'aceptado',
        EstadoAsignacion.enCamino => 'encamino',
        EstadoAsignacion.enSitio => 'ensitio',
        EstadoAsignacion.cerrado => 'completado',
      };

  /// Convierte el `estado` de Grupo Momeba al ciclo de la app.
  static EstadoAsignacion desdeMomeba(String? estado) => switch (estado) {
        'asignado' => EstadoAsignacion.asignado,
        'aceptado' => EstadoAsignacion.aceptado,
        'encamino' => EstadoAsignacion.enCamino,
        'ensitio' => EstadoAsignacion.enSitio,
        'completado' || 'pendiente' || 'cancelado' => EstadoAsignacion.cerrado,
        _ => EstadoAsignacion.pendienteAsignacion,
      };
}

/// Estado final según el `estado` de Grupo Momeba (solo si ya se cerró).
EstadoServicio? estadoFinalDesdeMomeba(String? estado) => switch (estado) {
      'completado' => EstadoServicio.completado,
      'pendiente' => EstadoServicio.pendiente,
      'cancelado' => EstadoServicio.cancelado,
      _ => null,
    };

/// Documento de Firestore (colección `servicios`) de Grupo Momeba, el mismo
/// que captura el panel web. Los nombres de campo son los del panel
/// (cliente, dir, tel, equipo, serie, falla, estado, tecnicoId…); aquí se
/// traducen al modelo de la app.
class ServicioAsignado {
  final String id;
  final String folio;
  final EstadoAsignacion estadoAsignacion;
  final EstadoServicio? estadoFinal;

  final String? technicianId;

  // Cliente y equipo (suficiente para mostrar resumen antes de llegar a sitio)
  final String clienteNombre;
  final String clienteDireccion;
  final String? clienteTelefono;
  final String? clienteCorreo;
  final double? clienteLat;
  final double? clienteLng;

  final String equipoTipo;
  final String marca;
  final String modelo;
  final String numeroSerie;
  final String fallaReportada;

  /// 'garantia' o 'cargo' (con costo al cliente).
  final String tipoServicio;

  final DateTime fechaCreacion;
  final DateTime? fechaAsignado;
  final DateTime? fechaAceptado;
  final DateTime? fechaEnCamino;
  final DateTime? fechaEnSitio;
  final DateTime? fechaCierre;

  final String? pdfUrl;
  final String? videoFallaUrl;
  final String? fotoEquipoUrl;
  final String? fotoPlacaUrl;
  final String? fotoFallaUrl;
  final List<String> refaccionesUsadas;
  final List<String> refaccionesFaltantes;
  final String? motivoPendiente;
  final int refrendos;

  /// Fecha futura programada para atender el servicio (reagendado).
  final DateTime? fechaProgramada;

  /// Proyecto de Grupo Momeba (marca · subservicio).
  final String? empresaId;
  String? get proyectoId => empresaId;

  /// Hora programada ("10:00") si el panel la capturó.
  final String? hora;

  /// Clave de la liga de seguimiento del cliente (servicio.html?o=…).
  final String? seguimiento;

  /// Cuándo avisó el técnico "Estoy llegando" y a qué hora calcula llegar.
  final DateTime? avisoLlegando;
  final DateTime? llegadaEstimada;

  /// Foto del lugar cuando la llegada se marcó a mano lejos del domicilio.
  final String? fotoLugarUrl;

  /// Bloque de visita acordado con el cliente, p. ej. "10:00-12:00".
  final String? ventana;

  /// El domicilio ya se comprobó: un técnico llegó ahí con GPS.
  final bool ubicacionValidada;

  /// Servicio de práctica (demo para técnicos) creado desde el panel.
  final bool demo;

  /// Horario para mostrar: el bloque ("10:00 a 12:00") o la hora exacta.
  String? get horarioTexto => ventana != null && ventana!.contains('-') ? ventana!.replaceFirst('-', ' a ') : hora;

  /// Liga pública para que el cliente siga su orden, escriba y llame.
  String? get ligaSeguimiento => seguimiento == null || seguimiento!.isEmpty ? null : MomebaConfig.ligaSeguimiento(seguimiento!);

  const ServicioAsignado({
    required this.id,
    required this.folio,
    required this.estadoAsignacion,
    this.estadoFinal,
    this.technicianId,
    required this.clienteNombre,
    required this.clienteDireccion,
    this.clienteTelefono,
    this.clienteCorreo,
    this.clienteLat,
    this.clienteLng,
    required this.equipoTipo,
    required this.marca,
    required this.modelo,
    required this.numeroSerie,
    required this.fallaReportada,
    this.tipoServicio = 'garantia',
    required this.fechaCreacion,
    this.fechaAsignado,
    this.fechaAceptado,
    this.fechaEnCamino,
    this.fechaEnSitio,
    this.fechaCierre,
    this.pdfUrl,
    this.videoFallaUrl,
    this.fotoEquipoUrl,
    this.fotoPlacaUrl,
    this.fotoFallaUrl,
    this.refaccionesUsadas = const [],
    this.refaccionesFaltantes = const [],
    this.motivoPendiente,
    this.refrendos = 0,
    this.fechaProgramada,
    this.empresaId,
    this.hora,
    this.seguimiento,
    this.avisoLlegando,
    this.llegadaEstimada,
    this.fotoLugarUrl,
    this.ventana,
    this.ubicacionValidada = false,
    this.demo = false,
  });

  /// Fecha de captura del panel: "2026-11-06" (+ "10:00") o ISO completo.
  static DateTime? _fecha(dynamic v, [String? hora]) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      final t = v.toDate(); // Timestamp de Firestore
      if (t is DateTime) return t;
    } catch (_) {}
    final s = v.toString();
    if (s.length == 10 && hora != null && RegExp(r'^\d{1,2}:\d{2}$').hasMatch(hora)) {
      return DateTime.tryParse('${s}T${hora.padLeft(5, '0')}:00');
    }
    return DateTime.tryParse(s);
  }

  static String _txt(dynamic v) => v == null ? '' : v.toString();

  factory ServicioAsignado.fromMap(String id, Map<String, dynamic> map) {
    final estado = map['estado'] as String?;
    final hora = map['hora'] as String?;
    return ServicioAsignado(
      id: id,
      folio: _txt(map['folio']),
      estadoAsignacion: EstadoAsignacionX.desdeMomeba(estado),
      estadoFinal: estadoFinalDesdeMomeba(estado),
      technicianId: map['tecnicoId'] as String?,
      clienteNombre: _txt(map['cliente']),
      clienteDireccion: _txt(map['dir']),
      clienteTelefono: (map['tel'] as String?)?.trim().isEmpty ?? true ? null : map['tel'] as String,
      clienteCorreo: map['correoCliente'] as String?,
      clienteLat: (map['lat'] as num?)?.toDouble(),
      clienteLng: (map['lng'] as num?)?.toDouble(),
      equipoTipo: _txt(map['equipo']),
      marca: _txt(map['marca']),
      modelo: _txt(map['modelo']),
      numeroSerie: _txt(map['serie']),
      fallaReportada: _txt(map['falla']),
      tipoServicio: (map['tipo'] as String?) ?? 'garantia',
      fechaCreacion: _fecha(map['creadoTxt']) ?? _fecha(map['creado']) ?? DateTime.now(),
      fechaAsignado: _fecha(map['creadoTxt']),
      fechaAceptado: _fecha(map['fechaAceptado']),
      fechaEnCamino: _fecha(map['fechaEnCamino']),
      fechaEnSitio: _fecha(map['fechaEnSitio']),
      fechaCierre: _fecha(map['fechaCierre']),
      pdfUrl: map['pdfUrl'] as String?,
      videoFallaUrl: map['videoFallaUrl'] as String?,
      fotoEquipoUrl: map['fotoEquipoUrl'] as String?,
      fotoPlacaUrl: map['fotoPlacaUrl'] as String?,
      fotoFallaUrl: map['fotoFallaUrl'] as String?,
      refaccionesUsadas: (map['refaccionesUsadas'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      refaccionesFaltantes: (map['refaccionesFaltantes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      motivoPendiente: map['motivoPendiente'] as String?,
      refrendos: (map['refrendos'] as num?)?.toInt() ?? 0,
      fechaProgramada: _fecha(map['fecha'], hora),
      empresaId: map['proyectoId'] as String?,
      hora: hora,
      seguimiento: map['seguimiento'] as String?,
      avisoLlegando: _fecha(map['avisoLlegando']),
      llegadaEstimada: _fecha(map['llegadaEstimada']),
      fotoLugarUrl: map['fotoLugarUrl'] as String?,
      ventana: map['ventana'] as String?,
      ubicacionValidada: map['ubicacionValidada'] == true,
      demo: map['demo'] == true,
    );
  }

  ServicioAsignado copyWith({
    EstadoAsignacion? estadoAsignacion,
    EstadoServicio? estadoFinal,
    String? technicianId,
    DateTime? fechaAsignado,
    DateTime? fechaAceptado,
    DateTime? fechaEnCamino,
    DateTime? fechaEnSitio,
    DateTime? fechaCierre,
    String? pdfUrl,
    String? videoFallaUrl,
    DateTime? fechaProgramada,
  }) {
    return ServicioAsignado(
      id: id,
      folio: folio,
      estadoAsignacion: estadoAsignacion ?? this.estadoAsignacion,
      estadoFinal: estadoFinal ?? this.estadoFinal,
      technicianId: technicianId ?? this.technicianId,
      clienteNombre: clienteNombre,
      clienteDireccion: clienteDireccion,
      clienteTelefono: clienteTelefono,
      clienteCorreo: clienteCorreo,
      clienteLat: clienteLat,
      clienteLng: clienteLng,
      equipoTipo: equipoTipo,
      marca: marca,
      modelo: modelo,
      numeroSerie: numeroSerie,
      fallaReportada: fallaReportada,
      tipoServicio: tipoServicio,
      fechaCreacion: fechaCreacion,
      fechaAsignado: fechaAsignado ?? this.fechaAsignado,
      fechaAceptado: fechaAceptado ?? this.fechaAceptado,
      fechaEnCamino: fechaEnCamino ?? this.fechaEnCamino,
      fechaEnSitio: fechaEnSitio ?? this.fechaEnSitio,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      videoFallaUrl: videoFallaUrl ?? this.videoFallaUrl,
      fotoEquipoUrl: fotoEquipoUrl,
      fotoPlacaUrl: fotoPlacaUrl,
      fotoFallaUrl: fotoFallaUrl,
      refaccionesUsadas: refaccionesUsadas,
      refaccionesFaltantes: refaccionesFaltantes,
      motivoPendiente: motivoPendiente,
      refrendos: refrendos,
      fechaProgramada: fechaProgramada ?? this.fechaProgramada,
      empresaId: empresaId,
      hora: hora,
      seguimiento: seguimiento,
      avisoLlegando: avisoLlegando,
      llegadaEstimada: llegadaEstimada,
      fotoLugarUrl: fotoLugarUrl,
      ventana: ventana,
      ubicacionValidada: ubicacionValidada,
      demo: demo,
    );
  }
}
