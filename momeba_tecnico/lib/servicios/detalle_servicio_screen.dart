import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:momeba_core/momeba_core.dart';

import '../providers/providers.dart';
import '../services/aviso_cliente.dart';
import '../services/notificaciones_locales.dart';
import '../widgets/fotos_servicio.dart';
import 'verificacion_qr_screen.dart';

const _indigo = Color(0xFF2A2F6B);
const _verde = Color(0xFF2E7D32);
const _amarillo = Color(0xFFF9A825);
const _turquesa = Color(0xFF1B7A76);

/// Umbral de llegada: dentro de este radio del domicilio del cliente se
/// habilita "Iniciar servicio".
const double _umbralLlegadaMetros = 100;

/// Más lejos que esto, marcar la llegada a mano pide una foto del lugar.
const double _umbralFotoMetros = 250;

class DetalleServicioScreen extends ConsumerStatefulWidget {
  const DetalleServicioScreen({super.key, required this.servicioId});

  final String servicioId;

  @override
  ConsumerState<DetalleServicioScreen> createState() => _DetalleServicioScreenState();
}

class _DetalleServicioScreenState extends ConsumerState<DetalleServicioScreen> {
  StreamSubscription<Position>? _posicionSub;
  double? _distanciaMetros;
  bool _procesando = false;

  @override
  void dispose() {
    _posicionSub?.cancel();
    super.dispose();
  }

  /// Normaliza un teléfono de México a formato internacional para wa.me.
  String _telWa(String tel) {
    var t = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.length == 10) return '521$t';
    if (t.length == 12 && t.startsWith('52')) return '521${t.substring(2)}';
    return t;
  }

  Future<void> _confirmarPorWhatsApp(ServicioAsignado s) async {
    if (s.clienteTelefono == null) return;
    final msj = Uri.encodeComponent(
        'Hola ${s.clienteNombre}, soy su técnico de Grupo Momeba para el servicio ${s.folio} '
        '(${s.equipoTipo} ${s.marca}). ¿Me confirma que se encontrará en el domicilio '
        'para agendar mi visita? — Grupo Momeba · Propósito sin límites');
    final uri = Uri.parse('https://wa.me/${_telWa(s.clienteTelefono!)}?text=$msj');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmarPorLlamada(ServicioAsignado s) async {
    if (s.clienteTelefono == null) return;
    final uri = Uri(scheme: 'tel', path: s.clienteTelefono!);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Deja elegir Google Maps o Waze y (opcional) recuerda la elección
  /// en tecnicos/{uid}.navPreferida para no volver a preguntar.
  Future<String?> _elegirNavegador() async {
    final tecnico = ref.read(tecnicoActualProvider).value;
    if (tecnico?.navPreferida == 'maps' || tecnico?.navPreferida == 'waze') {
      return tecnico!.navPreferida;
    }
    bool recordar = true;
    return showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('¿Con qué app quieres navegar?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.map, color: Color(0xFF34A853)),
              title: const Text('Google Maps'),
              onTap: () => Navigator.pop(c, 'maps'),
            ),
            ListTile(
              leading: const Icon(Icons.navigation, color: Color(0xFF33CCFF)),
              title: const Text('Waze'),
              onTap: () => Navigator.pop(c, 'waze'),
            ),
            CheckboxListTile(
              value: recordar,
              onChanged: (v) => setD(() => recordar = v ?? true),
              title: const Text('Recordar mi elección', style: TextStyle(fontSize: 13.5)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]),
        ),
      ),
    ).then((eleccion) async {
      if (eleccion != null && recordar && tecnico != null) {
        await ref.read(tecnicoRepositoryProvider).actualizarNavPreferida(tecnico.uid, eleccion);
      }
      return eleccion;
    });
  }

  Future<void> _abrirNavegacion(String app, double lat, double lng) async {
    final uri = app == 'waze'
        ? Uri.parse('https://waze.com/ul?ll=' '$lat,$lng&navigate=yes')
        : Uri.parse('google.navigation:q=' '$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(Uri.parse('geo:' '$lat,$lng?q=$lat,$lng'),
          mode: LaunchMode.externalApplication);
    }
  }

  /// "Estoy llegando": pasa a En camino con hora estimada (la ve el cliente en su página)
  /// y abre WhatsApp con el aviso y la liga de seguimiento.
  Future<void> _estoyLlegando(ServicioAsignado s) async {
    final minutos = await AvisoCliente.elegirMinutos(context);
    if (minutos == null || !mounted) return;
    setState(() => _procesando = true);
    try {
      await ref.read(servicioRepositoryProvider).avisarLlegando(s.id, minutos);
      if (s.clienteLat != null && s.clienteLng != null && await _asegurarPermisoUbicacion()) _iniciarRastreo(s);
      if (s.clienteTelefono != null) {
        await AvisoCliente.whatsapp(s, AvisoCliente.textoLlegando(s, DateTime.now().add(Duration(minutes: minutos))));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Aviso guardado. El cliente no tiene teléfono; lo verá en su página de seguimiento.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo avisar: $e')));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// Llegada marcada a mano. Lejos del domicilio (o sin GPS) pide una foto del lugar como evidencia.
  Future<void> _llegadaManual(ServicioAsignado s) async {
    setState(() => _procesando = true);
    try {
      Position? pos;
      if (await _asegurarPermisoUbicacion()) {
        try {
          pos = await Geolocator.getCurrentPosition(
                  locationSettings: const LocationSettings(accuracy: LocationAccuracy.high))
              .timeout(const Duration(seconds: 15));
        } catch (_) {}
      }
      double? d;
      if (pos != null && s.clienteLat != null && s.clienteLng != null) {
        d = distanciaMetros(pos.latitude, pos.longitude, s.clienteLat!, s.clienteLng!);
      }
      final repo = ref.read(servicioRepositoryProvider);
      if (d != null && d <= _umbralFotoMetros) {
        await repo.marcarEnSitio(s.id, distancia: d);
        return;
      }
      if (!mounted) return;
      final dist = d;
      final seguir = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Guarda evidencia de tu visita'),
          content: Text(dist == null
              ? 'No pudimos confirmar tu ubicación. Toma una foto del lugar (fachada o número exterior) como comprobante.'
              : 'Estás a ${dist >= 1000 ? '${(dist / 1000).toStringAsFixed(1)} km' : '${dist.round()} m'} del domicilio registrado. '
                  'Toma una foto del lugar (fachada o número exterior) como comprobante.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tomar foto')),
          ],
        ),
      );
      if (seguir != true) return;
      final archivo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      final url = await ref.read(storageServiceProvider).subirFotoServicio(
          s.id, 'lugar_llegada_${DateTime.now().millisecondsSinceEpoch}.jpg', bytes);
      await repo.marcarEnSitioManual(s.id, distancia: dist, lat: pos?.latitude, lng: pos?.longitude, fotoUrl: url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo marcar la llegada: $e')));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _avisarLlegada(ServicioAsignado s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 10),
      content: const Text('Llegaste al domicilio. Ya puedes iniciar el servicio.'),
      action: s.clienteTelefono == null
          ? null
          : SnackBarAction(label: 'Avisar al cliente', onPressed: () => AvisoCliente.whatsapp(s, AvisoCliente.textoLlegue(s))),
    ));
  }

  Future<bool> _asegurarPermisoUbicacion() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    return permiso == LocationPermission.always || permiso == LocationPermission.whileInUse;
  }

  Future<void> _acudir(ServicioAsignado s) async {
    if (!await _asegurarPermisoUbicacion()) return;
    final navApp = await _elegirNavegador();
    if (navApp == null) return; // canceló el diálogo
    setState(() => _procesando = true);
    try {
      await ref.read(servicioRepositoryProvider).marcarEnCamino(s.id);

      if (s.clienteLat != null && s.clienteLng != null) {
        await _abrirNavegacion(navApp, s.clienteLat!, s.clienteLng!);
      }

      _iniciarRastreo(s);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _iniciarRastreo(ServicioAsignado s) {
    final String servicioId = s.id;
    final double? clienteLat = s.clienteLat;
    final double? clienteLng = s.clienteLng;
    _posicionSub?.cancel();
    _posicionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 18),
    ).listen((posicion) async {
      await ref.read(servicioRepositoryProvider).actualizarTracking(servicioId, posicion.latitude, posicion.longitude);

      if (clienteLat == null || clienteLng == null) return;
      final distancia = distanciaMetros(posicion.latitude, posicion.longitude, clienteLat, clienteLng);
      if (mounted) setState(() => _distanciaMetros = distancia);

      if (distancia <= _umbralLlegadaMetros) {
        await _posicionSub?.cancel(); // se detiene por completo, no solo se oculta
        await ref.read(servicioRepositoryProvider).marcarEnSitio(servicioId, automatico: true, distancia: distancia);
        _avisarLlegada(s);
      }
    });
  }

  Future<void> _aceptar(String id) async {
    setState(() => _procesando = true);
    try {
      await ref.read(servicioRepositoryProvider).aceptar(id);
      await NotificacionesLocales.cancelarServicio(id);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicioAsync = ref.watch(servicioRepositoryProvider).observarUno(widget.servicioId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: const Text('Detalle de servicio'),
      ),
      body: StreamBuilder<ServicioAsignado?>(
        stream: servicioAsync,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final s = snap.data!;

          // Si la pantalla se abre (o se reabre tras editar/reasignar) y el
          // servicio ya está "en camino" pero el GPS no está corriendo —por
          // ejemplo, porque antes se llegó al domicilio y se apagó solo, y
          // ahora el admin volvió a tocar el servicio— lo reactivamos aquí
          // mismo, sin que el técnico tenga que volver a tocar "Acudir".
          if (s.estadoAsignacion == EstadoAsignacion.enCamino && _posicionSub == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _iniciarRastreo(s);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tarjeta('CLIENTE', [
                  _dato('Nombre', s.clienteNombre),
                  _dato('Dirección', s.clienteDireccion),
                  if (s.ubicacionValidada)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Icon(Icons.verified, size: 16, color: _turquesa),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text('Ubicación validada: un técnico ya llegó a este domicilio',
                              style: TextStyle(fontSize: 12.5, color: _turquesa, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  if (s.clienteTelefono != null) _dato('Teléfono', s.clienteTelefono!),
                ]),
                const SizedBox(height: 10),
                _tarjeta('EQUIPO Y FALLA', [
                  _dato('Equipo', '${s.equipoTipo} ${s.marca} ${s.modelo}'),
                  _dato('No. serie', s.numeroSerie),
                  _dato('Falla reportada', s.fallaReportada),
                ]),
                const SizedBox(height: 10),
                if (s.estadoAsignacion == EstadoAsignacion.enCamino ||
                    s.estadoAsignacion == EstadoAsignacion.enSitio ||
                    s.estadoAsignacion == EstadoAsignacion.cerrado) ...[
                  FotosServicioCard(
                    servicioId: s.id,
                    soloLectura: s.estadoAsignacion == EstadoAsignacion.cerrado,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                if (s.fechaProgramada != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEDEFFA), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                        '📅 Programado para: '
                        '${s.fechaProgramada!.day}/${s.fechaProgramada!.month}/${s.fechaProgramada!.year}'
                        '${s.horarioTexto != null && s.horarioTexto!.isNotEmpty ? ' · ${s.horarioTexto}' : ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: _indigo)),
                  ),
                if (s.estadoAsignacion == EstadoAsignacion.asignado) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _verde, foregroundColor: Colors.white),
                    onPressed: _procesando ? null : () => _aceptar(s.id),
                    icon: const Icon(Icons.check),
                    label: const Text('Aceptar servicio'),
                  ),
                ],
                if (s.estadoAsignacion == EstadoAsignacion.aceptado) ...[
                  if (s.clienteTelefono != null) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Confirma el servicio con el cliente antes de salir:',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF4A4F63))),
                    ),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                          onPressed: _procesando ? null : () => _confirmarPorWhatsApp(s),
                          icon: const Icon(Icons.chat),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _indigo, foregroundColor: Colors.white),
                          onPressed: _procesando ? null : () => _confirmarPorLlamada(s),
                          icon: const Icon(Icons.phone),
                          label: const Text('Llamar'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _turquesa, foregroundColor: Colors.white),
                    onPressed: _procesando ? null : () => _estoyLlegando(s),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Estoy llegando'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
                    onPressed: _procesando ? null : () => _acudir(s),
                    icon: const Icon(Icons.directions),
                    label: const Text('Acudir'),
                  ),
                ],
                if (s.estadoAsignacion == EstadoAsignacion.enCamino) ...[
                  const _EnCaminoAviso(),
                  const SizedBox(height: 8),
                  if (s.llegadaEstimada != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('El cliente espera tu llegada aprox. a las ${AvisoCliente.hora(s.llegadaEstimada!)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: _indigo)),
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _turquesa, foregroundColor: Colors.white),
                    onPressed: _procesando ? null : () => _estoyLlegando(s),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(s.llegadaEstimada == null ? 'Estoy llegando · avisar al cliente' : 'Cambiar hora de llegada'),
                  ),
                  const SizedBox(height: 8),
                  // Respaldo manual: si el GPS automático no detectó la
                  // llegada (por ejemplo, porque el admin reasignó el
                  // servicio mientras el técnico ya estaba en el domicilio),
                  // esto habilita "Iniciar servicio" sin esperar al GPS.
                  OutlinedButton.icon(
                    onPressed: _procesando ? null : () => _llegadaManual(s),
                    icon: const Icon(Icons.place),
                    label: const Text('Ya estoy en el domicilio'),
                  ),
                  if (_distanciaMetros != null) ...[
                    const SizedBox(height: 8),
                    Text('Distancia al domicilio: ${_distanciaMetros!.toStringAsFixed(0)} m',
                        textAlign: TextAlign.center),
                  ],
                ],
                if (s.estadoAsignacion == EstadoAsignacion.enSitio)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _amarillo, foregroundColor: Colors.black),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => VerificacionQrScreen(servicio: s))),
                    icon: const Icon(Icons.assignment_turned_in),
                    label: const Text('Iniciar servicio'),
                  ),
                if (s.estadoAsignacion == EstadoAsignacion.cerrado)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Este servicio ya fue cerrado.', textAlign: TextAlign.center),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tarjeta(String titulo, List<Widget> hijos) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD8DBE8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(color: _indigo, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
            const SizedBox(height: 8),
            ...hijos,
          ],
        ),
      );

  Widget _dato(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: const DefaultTextStyle.fallback().style.copyWith(color: Colors.black87, fontSize: 13.5),
            children: [
              TextSpan(text: '$etiqueta: ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: valor),
            ],
          ),
        ),
      );
}

class _EnCaminoAviso extends StatelessWidget {
  const _EnCaminoAviso();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF4F5FA), borderRadius: BorderRadius.circular(8)),
      child: const Column(
        children: [
          Icon(Icons.local_shipping_outlined, color: _indigo),
          SizedBox(height: 6),
          Text(
            'Vas en camino. El centro de operaciones ve tu ubicación en el mapa. '
            'Si quieres, avísale al cliente por WhatsApp. En cuanto llegues al '
            'domicilio se habilitará "Iniciar servicio".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF4A4F63)),
          ),
        ],
      ),
    );
  }
}
