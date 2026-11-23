import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momeba_core/momeba_core.dart';

import '../providers/providers.dart';
import '../tema.dart';
import 'detalle_servicio_screen.dart';

const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

/// Agenda por día: pestañas Hoy + los 6 días siguientes y una línea de horas
/// con cada servicio en su bloque de visita.
class AgendadosScreen extends ConsumerWidget {
  const AgendadosScreen({super.key});

  static int? _horaDe(ServicioAsignado s) {
    final v = s.ventana ?? s.hora ?? '';
    final h = int.tryParse(v.split(':').first.trim());
    if (h != null && h >= 0 && h < 24) return h;
    final f = s.fechaProgramada;
    return f == null ? null : f.hour;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoy = DateUtils.dateOnly(DateTime.now());
    final dias = List.generate(7, (i) => hoy.add(Duration(days: i)));
    final servicios = ref.watch(serviciosAsignadosProvider);
    return DefaultTabController(
      length: dias.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agendados'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Momeba.turquesaOscuro,
            unselectedLabelColor: Momeba.tinta,
            indicatorColor: Momeba.turquesa,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            tabs: [
              for (var i = 0; i < dias.length; i++)
                Tab(text: i == 0 ? 'Hoy' : i == 1 ? 'Mañana' : '${_dias[dias[i].weekday - 1]} ${dias[i].day}'),
            ],
          ),
        ),
        body: servicios.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (lista) => TabBarView(children: [
            for (final d in dias)
              _Dia(
                servicios: lista.where((s) {
                  final f = s.fechaProgramada;
                  return f != null && DateUtils.isSameDay(f, d);
                }).toList(),
                esHoy: DateUtils.isSameDay(d, hoy),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({required this.servicios, required this.esHoy});
  final List<ServicioAsignado> servicios;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    final porHora = <int, List<ServicioAsignado>>{};
    final sinHora = <ServicioAsignado>[];
    for (final s in servicios) {
      final h = AgendadosScreen._horaDe(s);
      if (h == null) {
        sinHora.add(s);
      } else {
        porHora.putIfAbsent(h, () => []).add(s);
      }
    }
    final usadas = porHora.keys.toList()..sort();
    final ini = usadas.isEmpty ? 7 : (usadas.first < 7 ? usadas.first : 7);
    final fin = usadas.isEmpty ? 20 : (usadas.last > 20 ? usadas.last : 20);
    final ahora = DateTime.now().hour;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 24),
      children: [
        if (servicios.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
            child: Text('Sin servicios agendados este día.', style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final s in sinHora) Padding(padding: const EdgeInsets.only(left: 72, bottom: 8), child: _Bloque(s: s)),
        for (var h = ini; h <= fin; h++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 64,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Text('$h hs',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: esHoy && h == ahora ? Momeba.turquesaOscuro : Momeba.texto,
                          fontWeight: esHoy && h == ahora ? FontWeight.w700 : FontWeight.w400)),
                ),
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Momeba.linea))),
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Column(children: [
                    for (final s in porHora[h] ?? const <ServicioAsignado>[])
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: _Bloque(s: s)),
                  ]),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({required this.s});
  final ServicioAsignado s;

  @override
  Widget build(BuildContext context) {
    final color = s.estadoAsignacion == EstadoAsignacion.asignado ? Momeba.aviso : Momeba.turquesaOscuro;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => DetalleServicioScreen(servicioId: s.id))),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(s.clienteNombre,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(s.horarioTexto ?? '', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 2),
            Text('${s.folio} · ${s.equipoTipo} ${s.marca}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            if (s.clienteDireccion.isNotEmpty)
              Text(s.clienteDireccion,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}
