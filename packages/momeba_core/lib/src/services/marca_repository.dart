import 'package:flutter/services.dart' show rootBundle;

import '../models/marca_servicio.dart';

/// Marca de la hoja de servicio: siempre Grupo Momeba, con su logotipo.
class MarcaRepository {
  static MarcaServicio? _cache;

  static Future<MarcaServicio> cargar([String? _]) async {
    if (_cache != null) return _cache!;
    try {
      final logo = (await rootBundle.load('assets/images/momeba_icono.png')).buffer.asUint8List();
      _cache = MarcaServicio.momeba.conLogo(logo);
    } catch (_) {
      _cache = MarcaServicio.momeba;
    }
    return _cache!;
  }
}
