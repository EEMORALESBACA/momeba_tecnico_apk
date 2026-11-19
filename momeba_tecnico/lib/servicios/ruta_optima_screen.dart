import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:momeba_core/momeba_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../services/aviso_cliente.dart';
import 'detalle_servicio_screen.dart';

const _indigo = Color(0xFF2A2F6B);
const _turquesa = Color(0xFF1B7A76);
const _gris = Color(0xFF4A4F63);

/// Minutos entre una parada y la siguiente al avisar "Estoy llegando" a varios clientes.
const _minutosEntreParadas = 30;

/// Varias órdenes en el mismo domicilio (a menos de esto) se atienden como una sola parada.
const _radioMismaParada = 40.0;

/// Una parada de la ruta: uno o más servicios en el mismo domicilio.
class _Parada {
  _Parada(this.servicios);
  final List<ServicioAsignado> servicios;
  double? distancia;
  ServicioAsignado get primero => servicios.first;
  double? get lat => primero.clienteLat;
  double? get lng => primero.clienteLng;
  bool get conUbicacion => lat != null && lng != null;
}

/// Ruta del día: paradas en orden (lista), ruta completa en Google Maps,
/// "Estoy llegando" a varios clientes a la vez y secciones de próximas,
/// por aceptar y terminadas hoy.
class RutaOptimaScreen extends ConsumerStatefulWidget {
  const RutaOptimaScreen({super.key});

  @override
  ConsumerState<RutaOptimaScreen> createState() => _RutaOptimaScreenState();
}

class _RutaOptimaScreenState extends ConsumerState<RutaOptimaScreen> {
  static const _prefOrden = 'ruta_mas_corta';

  Position? _miPosicion;
  String? _errorUbicacion;
  bool _cargando = true;
  bool _masCorta = false; // false: del más lejano al más cercano (orden original)
  bool _avisando = false;
  final Set<String> _seleccion = {};

  @override
  void initState() {
    super.initState();
    _leerPreferencia();
    _obtenerUbicacion();
  }

  Future<void> _leerPreferencia() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool(_prefOrden);
      if (v != null && mounted) setState(() => _masCorta = v);
    } catch (_) {}
  }

  Future<void> _guardarPreferencia(bool v) async {
    setState(() => _masCorta = v);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefOrden, v);
    } catch (_) {}
  }

  Future<void> _obtenerUbicacion() async {
    setState(() {
      _cargando = true;
      _errorUbicacion = null;
    });
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        setState(() {
          _errorUbicacion = 'Activa el permiso de ubicación para ordenar tu ruta.';
          _cargando = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() {
        _miPosicion = pos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorUbicacion = 'No se pudo obtener tu ubicación.';
        _cargando = false;
      });
    }
  }

  /// Junta en una parada las órdenes que están en el mismo domicilio.
  List<_Parada> _agrupar(List<ServicioAsignado> servicios) {
    final paradas = <_Parada>[];
    for (final s in servicios) {
      _Parada? misma;
      if (s.clienteLat != null && s.clienteLng != null) {
        for (final p in paradas) {
          if (p.conUbicacion &&
              distanciaMetros(p.lat!, p.lng!, s.clienteLat!, s.clienteLng!) <= _radioMismaParada) {
            misma = p;
            break;
          }
        }
      }
      if (misma != null) {
        misma.servicios.add(s);
      } else {
        paradas.add(_Parada([s]));
      }
    }
    return paradas;
  }

  /// Ordena las paradas: del más lejano al más cercano, o la ruta más corta
  /// (siempre a la parada más cercana desde donde vas). Las que no tienen
  /// ubicación quedan al final.
  List<_Parada> _ordenar(List<_Parada> paradas) {
    final yo = _miPosicion;
    final con = paradas.where((p) => p.conUbicacion).toList();
    final sin = paradas.where((p) => !p.conUbicacion).toList();
    if (yo == null) return [...con, ...sin];
    for (final p in con) {
      p.distancia = distanciaMetros(yo.latitude, yo.longitude, p.lat!, p.lng!);
    }
    if (!_masCorta) {
      con.sort((a, b) => b.distancia!.compareTo(a.distancia!));
      return [...con, ...sin];
    }
    final orden = <_Parada>[];
    var lat = yo.latitude, lng = yo.longitude;
    final resto = [...con];
    while (resto.isNotEmpty) {
      resto.sort((a, b) =>
          distanciaMetros(lat, lng, a.lat!, a.lng!).compareTo(distanciaMetros(lat, lng, b.lat!, b.lng!)));
      final sig = resto.removeAt(0);
      orden.add(sig);
      lat = sig.lat!;
      lng = sig.lng!;
    }
    return [...orden, ...sin];
  }

  /// Abre la ruta completa en Google Maps (hasta 10 paradas).
  Future<void> _abrirRutaEnMapa(List<_Parada> paradas) async {
    final puntos = paradas.where((p) => p.conUbicacion).take(10).toList();
    if (puntos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ninguna parada tiene ubicación registrada.')));
      return;
    }
    final destino = puntos.last;
    final intermedias = puntos.sublist(0, puntos.length - 1).map((p) => '${p.lat},${p.lng}').join('|');
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&travelmode=driving'
        '&destination=${destino.lat},${destino.lng}'
        '${intermedias.isEmpty ? '' : '&waypoints=${Uri.encodeComponent(intermedias)}'}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// "Estoy llegando" a varios clientes: el primero con los minutos que elijas y
  /// cada siguiente parada [_minutosEntreParadas] minutos después.
  Future<void> _llegandoVarios(List<_Parada> ordenadas) async {
    final servicios = [
      for (final p in ordenadas)
        for (final s in p.servicios)
          if (_seleccion.contains(s.id)) s
    ];
    if (servicios.isEmpty) return;
    final minutos = await AvisoCliente.elegirMinutos(context, cuantos: servicios.length);
    if (minutos == null || !mounted) return;
    setState(() => _avisando = true);
    final repo = ref.read(servicioRepositoryProvider);
    final avisos = <({ServicioAsignado s, DateTime llega})>[];
    var parada = -1;
    String? ultimaParada;
    try {
      for (final s in servicios) {
        final idParada = ordenadas.firstWhere((p) => p.servicios.contains(s)).primero.id;
        if (idParada != ultimaParada) {
          parada++;
          ultimaParada = idParada;
        }
        final m = minutos + parada * _minutosEntreParadas;
        await repo.avisarLlegando(s.id, m);
        avisos.add((s: s, llega: DateTime.now().add(Duration(minutes: m))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo avisar a todos: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _avisando = false;
          _seleccion.clear();
        });
      }
    }
    if (!mounted || avisos.isEmpty) return;
    final enviados = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Avisa por WhatsApp',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _indigo)),
              const SizedBox(height: 4),
              const Text('Ya ven la hora en su página de seguimiento. Toca cada uno para mandarle el mensaje.',
                  style: TextStyle(fontSize: 13.5, color: _gris)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final a in avisos)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(enviados.contains(a.s.id) ? Icons.check_circle : Icons.chat,
                          color: enviados.contains(a.s.id) ? _turquesa : const Color(0xFF25D366)),
                      title: Text('${a.s.clienteNombre} · ${a.s.folio}'),
                      subtitle: Text('Llega aprox. ${AvisoCliente.hora(a.llega)}'),
                      enabled: a.s.clienteTelefono != null,
                      trailing: a.s.clienteTelefono == null ? const Text('Sin teléfono') : const Icon(Icons.send),
                      onTap: () async {
                        await AvisoCliente.whatsapp(a.s, AvisoCliente.textoLlegando(a.s, a.llega));
                        setS(() => enviados.add(a.s.id));
                      },
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _abrir(_Parada p) {
    if (p.servicios.length == 1) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleServicioScreen(servicioId: p.primero.id)));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < p.servicios.length; i++)
            ListTile(
              leading: CircleAvatar(backgroundColor: _turquesa, foregroundColor: Colors.white, child: Text(_letra(i))),
              title: Text('${p.servicios[i].folio} · ${p.servicios[i].clienteNombre}'),
              subtitle: Text(p.servicios[i].equipoTipo),
              onTap: () {
                Navigator.pop(c);
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DetalleServicioScreen(servicioId: p.servicios[i].id)));
              },
            ),
        ]),
      ),
    );
  }

  static String _letra(int i) => String.fromCharCode(65 + (i % 26));

  static bool _puedeAvisar(ServicioAsignado s) =>
      s.estadoAsignacion == EstadoAsignacion.aceptado || s.estadoAsignacion == EstadoAsignacion.enCamino;

  static bool _esHoy(DateTime? d) {
    if (d == null) return false;
    final h = DateTime.now();
    return d.year == h.year && d.month == h.month && d.day == h.day;
  }

  @override
  Widget build(BuildContext context) {
    final activos = ref.watch(serviciosAsignadosProvider);
    final historial = ref.watch(historialServiciosProvider).value ?? const <ServicioAsignado>[];

    return activos.when(
      loading: () => Scaffold(appBar: _barra(const []), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: _barra(const []), body: Center(child: Text('Error: $e'))),
      data: (lista) {
        final proximas = lista
            .where((s) =>
                s.estadoAsignacion == EstadoAsignacion.aceptado ||
                s.estadoAsignacion == EstadoAsignacion.enCamino ||
                s.estadoAsignacion == EstadoAsignacion.enSitio)
            .toList();
        final porAceptar = lista.where((s) => s.estadoAsignacion == EstadoAsignacion.asignado).toList();
        final terminadas = historial
            .where((s) => s.estadoAsignacion == EstadoAsignacion.cerrado && _esHoy(s.fechaCierre))
            .toList();
        final paradas = _ordenar(_agrupar(proximas));
        _seleccion.removeWhere((id) => !proximas.any((s) => s.id == id && _puedeAvisar(s)));

        return Scaffold(
          appBar: _barra(paradas),
          floatingActionButton: _seleccion.isEmpty
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: _turquesa,
                  foregroundColor: Colors.white,
                  onPressed: _avisando ? null : () => _llegandoVarios(paradas),
                  icon: _avisando
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.notifications_active_outlined),
                  label: Text('Estoy llegando (${_seleccion.length})'),
                ),
          body: RefreshIndicator(
            onRefresh: _obtenerUbicacion,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
              children: [
                _resumen(paradas.length, proximas.length),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Más lejano primero'), icon: Icon(Icons.north_east)),
                    ButtonSegment(value: true, label: Text('Ruta más corta'), icon: Icon(Icons.route)),
                  ],
                  selected: {_masCorta},
                  onSelectionChanged: (v) => _guardarPreferencia(v.first),
                ),
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_errorUbicacion != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('$_errorUbicacion Las paradas se muestran sin ordenar por distancia.',
                        style: const TextStyle(color: Color(0xFFB42318), fontSize: 13)),
                  ),
                _titulo('Próximas paradas', paradas.length),
                if (paradas.isEmpty) _vacio('No tienes paradas pendientes por ahora.'),
                for (var i = 0; i < paradas.length; i++) _tarjetaParada(i, paradas[i]),
                if (porAceptar.isNotEmpty) ...[
                  _titulo('Por aceptar', porAceptar.length),
                  for (final s in porAceptar) _tarjetaSimple(s, const Color(0xFFF9A825), 'Acéptalo para sumarlo a tu ruta'),
                ],
                _titulo('Terminadas hoy', terminadas.length),
                if (terminadas.isEmpty) _vacio('Aún no cierras servicios hoy.'),
                for (final s in terminadas)
                  _tarjetaSimple(s, const Color(0xFF2E7D32), s.estadoFinal?.etiqueta ?? 'Cerrado'),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _barra(List<_Parada> paradas) => AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: const Text('Ruta del día'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Ver la ruta en Google Maps',
            onPressed: paradas.isEmpty ? null : () => _abrirRutaEnMapa(paradas),
          ),
          IconButton(icon: const Icon(Icons.my_location), onPressed: _obtenerUbicacion, tooltip: 'Actualizar mi ubicación'),
        ],
      );

  Widget _resumen(int paradas, int servicios) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _indigo, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.alt_route, color: Color(0xFF3FC1BB), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tu ruta tiene $paradas ${paradas == 1 ? 'parada' : 'paradas'}',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              Text('$servicios ${servicios == 1 ? 'servicio' : 'servicios'} por atender · marca varias para avisar "Estoy llegando"',
                  style: const TextStyle(color: Color(0xFFC9CCE3), fontSize: 12.5)),
            ]),
          ),
        ]),
      );

  Widget _titulo(String t, int n) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Text('$t ($n)',
            style: const TextStyle(color: _indigo, fontWeight: FontWeight.w800, letterSpacing: 0.5, fontSize: 14)),
      );

  Widget _vacio(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(t, style: const TextStyle(color: _gris)),
      );

  Widget _tarjetaParada(int i, _Parada p) {
    final avisables = p.servicios.where(_puedeAvisar).toList();
    final todos = avisables.isNotEmpty && avisables.every((s) => _seleccion.contains(s.id));
    final km = p.distancia == null
        ? null
        : p.distancia! < 1000
            ? '${p.distancia!.round()} m'
            : '${(p.distancia! / 1000).toStringAsFixed(1)} km';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrir(p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(backgroundColor: _indigo, foregroundColor: Colors.white, child: Text('${i + 1}')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.primero.clienteDireccion.isEmpty ? 'Sin dirección' : p.primero.clienteDireccion,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (p.servicios.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Parada agrupada · ${p.servicios.length} servicios',
                        style: const TextStyle(color: _turquesa, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 6),
                for (var j = 0; j < p.servicios.length; j++) _lineaServicio(p.servicios.length > 1 ? _letra(j) : null, p.servicios[j]),
                if (!p.conUbicacion)
                  const Text('Sin ubicación en el mapa', style: TextStyle(color: Color(0xFFB42318), fontSize: 12.5)),
              ]),
            ),
            Column(children: [
              if (km != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF3FC1BB).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                  child: Text(km, style: const TextStyle(fontWeight: FontWeight.w800, color: _turquesa, fontSize: 12.5)),
                ),
              if (avisables.isNotEmpty)
                Checkbox(
                  value: todos,
                  onChanged: (v) => setState(() {
                    for (final s in avisables) {
                      if (v == true) {
                        _seleccion.add(s.id);
                      } else {
                        _seleccion.remove(s.id);
                      }
                    }
                  }),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _lineaServicio(String? letra, ServicioAsignado s) {
    final hora = s.llegadaEstimada != null && s.estadoAsignacion == EstadoAsignacion.enCamino
        ? ' · llega ${AvisoCliente.hora(s.llegadaEstimada!)}'
        : (s.horarioTexto != null && s.horarioTexto!.isNotEmpty ? ' · cita ${s.horarioTexto}' : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '${letra != null ? '$letra · ' : ''}${s.folio} · ${s.clienteNombre} · ${s.equipoTipo}\n'
        '${s.estadoAsignacion.etiqueta}$hora',
        style: const TextStyle(fontSize: 13, color: _gris),
      ),
    );
  }

  Widget _tarjetaSimple(ServicioAsignado s, Color color, String nota) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: color, child: const Icon(Icons.build, color: Colors.white, size: 18)),
          title: Text('${s.folio} · ${s.clienteNombre}'),
          subtitle: Text('${s.equipoTipo} · $nota'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => DetalleServicioScreen(servicioId: s.id))),
        ),
      );
}
