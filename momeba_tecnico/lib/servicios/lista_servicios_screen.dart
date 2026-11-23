import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momeba_core/momeba_core.dart';

import '../providers/providers.dart';
import '../tema.dart';
import 'detalle_servicio_screen.dart';
import 'ruta_optima_screen.dart';

Color _colorAsignacion(EstadoAsignacion e) => switch (e) {
      EstadoAsignacion.asignado => Momeba.aviso,
      EstadoAsignacion.aceptado || EstadoAsignacion.enCamino || EstadoAsignacion.enSitio => Momeba.turquesaOscuro,
      _ => Momeba.texto,
    };

/// Lista en vivo (stream de Firestore) de los servicios asignados al técnico
/// logueado, en cualquier estado activo.
class ListaServiciosScreen extends ConsumerWidget {
  const ListaServiciosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicios = ref.watch(serviciosAsignadosProvider);
    final tecnico = ref.watch(tecnicoActualProvider).value;
    final nombre = (tecnico?.nombre ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis servicios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route),
            tooltip: 'Ruta del día',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RutaOptimaScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => cerrarSesionCompleta(ref),
          ),
        ],
      ),
      body: servicios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) {
          final activos = lista.where((s) => s.estadoAsignacion != EstadoAsignacion.asignado).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                lista.isEmpty
                    ? 'Sin servicios por ahora'
                    : '${lista.length} ${lista.length == 1 ? 'servicio' : 'servicios'} · $activos en curso',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (lista.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                    child: Column(children: [
                      Icon(Icons.inbox_outlined, size: 36, color: Momeba.texto.withValues(alpha: 0.6)),
                      const SizedBox(height: 10),
                      const Text('No tienes servicios asignados.', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Cuando tu coordinador te asigne uno, aparecerá aquí.',
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                )
              else
                for (final s in lista) ...[
                  TarjetaServicio(s: s),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class TarjetaServicio extends StatelessWidget {
  const TarjetaServicio({required this.s});
  final ServicioAsignado s;

  @override
  Widget build(BuildContext context) {
    final color = _colorAsignacion(s.estadoAsignacion);
    final horario = s.horarioTexto;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => DetalleServicioScreen(servicioId: s.id))),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(s.folio,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Momeba.texto, letterSpacing: 0.3)),
                    const SizedBox(width: 8),
                    if (s.demo) const Pastilla('PRÁCTICA', color: Momeba.indigo),
                    const Spacer(),
                    Pastilla(s.estadoAsignacion.etiqueta, color: color),
                  ]),
                  const SizedBox(height: 6),
                  Text(s.clienteNombre,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${s.equipoTipo} ${s.marca} ${s.modelo}'.trim(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (horario != null && horario.isNotEmpty) ...[
                      const Icon(Icons.schedule, size: 15, color: Momeba.texto),
                      const SizedBox(width: 4),
                      Text(horario, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 12),
                    ],
                    Icon(s.tipoServicio == 'cargo' ? Icons.payments_outlined : Icons.verified_user_outlined,
                        size: 15, color: Momeba.texto),
                    const SizedBox(width: 4),
                    Text(s.tipoServicio == 'cargo' ? 'Con cargo' : 'Garantía', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                  if (s.clienteDireccion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.place_outlined, size: 15, color: Momeba.texto),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(s.clienteDireccion,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ]),
                  ],
                ]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.chevron_right, color: Momeba.texto),
            ),
          ]),
        ),
      ),
    );
  }
}
