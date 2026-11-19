/// Técnico de Grupo Momeba: documento `usuarios/{uid}` con rol "tecnico".
/// Lo da de alta el Super Admin desde el panel web; la app no registra técnicos.
class Tecnico {
  final String uid;
  final String nombre;
  final String telefono;
  final String? correo;
  final String rol;
  final bool activo;
  final String? fotoUrl;
  final String? zona;

  /// Placas del vehículo con el que acude a los servicios.
  final String? placas;

  /// App de navegación preferida al acudir: 'maps' o 'waze'.
  final String? navPreferida;

  /// Ids de proyectos que puede ver ('*' = todos).
  final List<String> proyectos;

  /// Lecciones de capacitación (ids de Descargas tipo "capacitacion") que ya vio.
  final List<String> capacitacion;

  const Tecnico({
    required this.uid,
    required this.nombre,
    required this.telefono,
    this.correo,
    required this.rol,
    required this.activo,
    this.fotoUrl,
    this.zona,
    this.placas,
    this.navPreferida,
    this.proyectos = const [],
    this.capacitacion = const [],
  });

  bool get esTecnico => rol == 'tecnico';

  /// Puede usar la app: técnico activo.
  bool get habilitado => activo && esTecnico;

  /// Compatibilidad con pantallas heredadas.
  String? get selfieUrl => fotoUrl;

  factory Tecnico.fromMap(String uid, Map<String, dynamic> map) {
    final foto = map['fotoUrl'] as String? ?? map['foto'] as String?;
    return Tecnico(
      uid: uid,
      nombre: (map['nombre'] as String?) ?? '',
      telefono: (map['tel'] as String?) ?? '',
      correo: map['correo'] as String?,
      rol: (map['rol'] as String?) ?? '',
      activo: map['activo'] == true,
      // La foto puede venir como liga (app) o como imagen pequeña incrustada (panel web).
      fotoUrl: (foto != null && foto.isNotEmpty) ? foto : null,
      zona: map['zona'] as String?,
      placas: map['placas'] as String?,
      navPreferida: map['navPreferida'] as String?,
      proyectos: (map['proyectos'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      capacitacion: (map['capacitacion'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
