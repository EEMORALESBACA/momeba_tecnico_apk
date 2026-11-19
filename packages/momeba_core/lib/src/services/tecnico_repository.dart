import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tecnico.dart';

/// El técnico es un usuario de Grupo Momeba (`usuarios/{uid}`, rol "tecnico").
/// Su última ubicación vive en `ubicaciones/{uid}` y su credencial pública
/// (la que abre el QR) en `credenciales/{uid}`.
class TecnicoRepository {
  TecnicoRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('usuarios').doc(uid);

  Stream<Tecnico?> observar(String uid) => _doc(uid).snapshots().map(
        (doc) => doc.exists ? Tecnico.fromMap(doc.id, doc.data()!) : null,
      );

  Future<Tecnico?> leer(String uid) async {
    final d = await _doc(uid).get();
    return d.exists ? Tecnico.fromMap(d.id, d.data()!) : null;
  }

  /// Última ubicación conocida del técnico (para el mapa del panel).
  /// Funciona también en segundo plano, aunque su sesión de 2 h haya caducado.
  Future<void> actualizarUbicacion(String uid, double lat, double lng, {bool respaldo = false, String? nombre}) =>
      _db.collection('ubicaciones').doc(uid).set({
        'lat': lat,
        'lng': lng,
        'actualizado': DateTime.now().toIso8601String(),
        'respaldo': respaldo,
        if (nombre != null) 'nombre': nombre,
      }, SetOptions(merge: true));

  Future<void> actualizarNavPreferida(String uid, String app) => _doc(uid).update({'navPreferida': app});

  Future<void> actualizarPlacas(String uid, String placas) => _doc(uid).update({'placas': placas});

  /// Marca una lección de capacitación como vista (el panel ve el avance).
  Future<void> marcarLeccionVista(String uid, String leccionId) =>
      _doc(uid).update({'capacitacion': FieldValue.arrayUnion([leccionId])});

  /// Foto de perfil: liga del archivo en HostGator.
  Future<void> actualizarSelfie(String uid, String url) async {
    await _doc(uid).update({'fotoUrl': url});
    try {
      await _db.collection('credenciales').doc(uid).set({'foto': url}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> registrarVersion(String uid, String version) async {
    try {
      await _doc(uid).update({'appVersion': version, 'ultimoAcceso': DateTime.now().toIso8601String()});
    } catch (_) {}
  }
}
