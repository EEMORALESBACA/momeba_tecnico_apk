import 'package:cloud_firestore/cloud_firestore.dart';

/// Archivo que el administrador publica para los técnicos desde el panel web:
/// software de la marca, explosionados, manuales.
class Descarga {
  const Descarga({
    required this.id,
    required this.titulo,
    required this.url,
    this.descripcion,
    this.tipo = 'otro',
    this.marca,
    this.modelo,
    this.nombreArchivo,
    this.tamano,
    this.fecha,
  });

  final String id;
  final String titulo;
  final String url;
  final String? descripcion;
  final String tipo; // software | explosionado | manual | capacitacion | otro
  final String? marca;
  final String? modelo;
  final String? nombreArchivo;
  final int? tamano;
  final DateTime? fecha;

  String get tipoEtiqueta => switch (tipo) {
        'software' => 'Software',
        'explosionado' => 'Explosionado',
        'manual' => 'Manual',
        'capacitacion' => 'Capacitación',
        _ => 'Otro',
      };

  String get tamanoTexto {
    final t = tamano;
    if (t == null || t <= 0) return '';
    if (t < 1024 * 1024) return '${(t / 1024).toStringAsFixed(0)} KB';
    if (t < 1024 * 1024 * 1024) return '${(t / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(t / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  factory Descarga.fromMap(String id, Map<String, dynamic> m) => Descarga(
        id: id,
        titulo: (m['titulo'] as String?) ?? 'Archivo',
        url: (m['url'] as String?) ?? '',
        descripcion: m['descripcion'] as String?,
        tipo: (m['tipo'] as String?) ?? 'otro',
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        nombreArchivo: m['nombreArchivo'] as String?,
        tamano: (m['tamano'] as num?)?.toInt(),
        fecha: DateTime.tryParse((m['fechaTxt'] as String?) ?? ''),
      );
}

class DescargasRepository {
  DescargasRepository({FirebaseFirestore? firestore})
      : _col = (firestore ?? FirebaseFirestore.instance).collection('descargas');

  final CollectionReference<Map<String, dynamic>> _col;

  Stream<List<Descarga>> observar() => _col.snapshots().map((s) {
        final l = s.docs.map((d) => Descarga.fromMap(d.id, d.data())).where((d) => d.url.isNotEmpty).toList();
        l.sort((a, b) => (b.fecha ?? DateTime(2000)).compareTo(a.fecha ?? DateTime(2000)));
        return l;
      });
}
