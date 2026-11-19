import 'dart:typed_data';

/// Identidad visual con la que se emite la hoja de servicio.
class MarcaServicio {
  final String nombre;
  final String lema;
  final int colorPrimario; // ARGB, ej. 0xFF2A2F6B
  final int colorSecundario;
  final Uint8List? logoBytes;
  final String pie; // Línea de contacto al pie del PDF

  const MarcaServicio({
    required this.nombre,
    this.lema = '',
    required this.colorPrimario,
    required this.colorSecundario,
    this.logoBytes,
    required this.pie,
  });

  MarcaServicio conLogo(Uint8List? logo) => MarcaServicio(
        nombre: nombre,
        lema: lema,
        colorPrimario: colorPrimario,
        colorSecundario: colorSecundario,
        logoBytes: logo,
        pie: pie,
      );

  /// Paleta 7 · Índigo y turquesa.
  static const momeba = MarcaServicio(
    nombre: 'GRUPO MOMEBA',
    lema: 'PROPÓSITO SIN LÍMITES',
    colorPrimario: 0xFF2A2F6B,
    colorSecundario: 0xFF22918D,
    pie: 'grupomomeba.com  ·  contacto@grupomomeba.com  ·  Estado de México / CDMX',
  );

  /// '#033649' → 0xFF033649. Devuelve null si no es un color válido.
  static int? colorDesdeHex(String? hex) {
    if (hex == null) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : 0xFF000000 | v;
  }
}
