import 'package:flutter/material.dart';
import 'package:momeba_core/momeba_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mensajes al cliente por WhatsApp (se abren en el WhatsApp del técnico con el texto listo).
class AvisoCliente {
  AvisoCliente._();

  /// Teléfono de México a formato internacional para wa.me.
  static String telWa(String tel) {
    var t = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.length == 10) return '521$t';
    if (t.length == 12 && t.startsWith('52')) return '521${t.substring(2)}';
    return t;
  }

  static String hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _liga(ServicioAsignado s) {
    final l = s.ligaSeguimiento;
    return l == null ? '' : '\n\nSiga su servicio aquí: $l';
  }

  static String textoLlegando(ServicioAsignado s, DateTime llegada) =>
      'Hola ${s.clienteNombre}, soy su técnico de Grupo Momeba para el servicio ${s.folio} '
      '(${s.equipoTipo}). Voy en camino y llego aproximadamente a las ${hora(llegada)}. '
      'Por favor, que alguien pueda recibirme en el domicilio.${_liga(s)}';

  static String textoLlegue(ServicioAsignado s) =>
      'Hola ${s.clienteNombre}, ya estoy afuera de su domicilio para el servicio ${s.folio}. '
      '— Grupo Momeba${_liga(s)}';

  static Future<bool> whatsapp(ServicioAsignado s, String texto) async {
    if (s.clienteTelefono == null) return false;
    final uri = Uri.parse('https://wa.me/${telWa(s.clienteTelefono!)}?text=${Uri.encodeComponent(texto)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Pregunta en cuántos minutos llega. Regresa null si cancela.
  static Future<int?> elegirMinutos(BuildContext context, {int cuantos = 1}) => showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(cuantos > 1 ? 'Estoy llegando · $cuantos clientes' : 'Estoy llegando',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2A2F6B))),
              const SizedBox(height: 4),
              const Text('¿En cuánto tiempo llegas? El cliente verá la hora en su página de seguimiento.',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF4A4F63))),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final m in const [15, 30, 45, 60, 90])
                  ChoiceChip(
                    label: Text(m < 60 ? '$m min' : (m == 60 ? '1 hora' : '1 h 30')),
                    selected: false,
                    onSelected: (_) => Navigator.pop(c, m),
                  ),
              ]),
            ]),
          ),
        ),
      );
}
