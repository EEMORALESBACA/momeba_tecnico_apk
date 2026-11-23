import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momeba_core/momeba_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../tema.dart';
import '../widgets/foto_perfil.dart';
import 'agendados_screen.dart';
import 'capacitacion_screen.dart';
import 'descargas_screen.dart';
import 'detalle_servicio_screen.dart';
import 'lista_servicios_screen.dart';
import 'perfil_screen.dart';
import 'productividad_screen.dart';
import 'ruta_optima_screen.dart';

bool _enCurso(ServicioAsignado s) => switch (s.estadoAsignacion) {
      EstadoAsignacion.aceptado || EstadoAsignacion.enCamino || EstadoAsignacion.enSitio => true,
      _ => false,
    };

/// Pantalla principal del técnico: Inicio · Disponibles · Agendados · Más.
class HomeTabs extends ConsumerStatefulWidget {
  const HomeTabs({super.key});

  @override
  ConsumerState<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends ConsumerState<HomeTabs> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final lista = ref.watch(serviciosAsignadosProvider).value ?? const <ServicioAsignado>[];
    final nuevos = lista.where((s) => s.estadoAsignacion == EstadoAsignacion.asignado).length;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _InicioScreen(irADisponibles: () => setState(() => _tab = 1)),
          const _DisponiblesScreen(),
          const AgendadosScreen(),
          const _MasScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Momeba.linea))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(
              icon: Badge(isLabelVisible: nuevos > 0, label: Text('$nuevos'), child: const Icon(Icons.inventory_2_outlined)),
              selectedIcon: Badge(isLabelVisible: nuevos > 0, label: Text('$nuevos'), child: const Icon(Icons.inventory_2)),
              label: 'Disponibles',
            ),
            const NavigationDestination(icon: Icon(Icons.event_available_outlined), selectedIcon: Icon(Icons.event_available), label: 'Agendados'),
            const NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'Más'),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------- Inicio --------------------------------- */

class _InicioScreen extends ConsumerWidget {
  const _InicioScreen({required this.irADisponibles});
  final VoidCallback irADisponibles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicios = ref.watch(serviciosAsignadosProvider);
    final tecnico = ref.watch(tecnicoActualProvider).value;
    final nombre = (tecnico?.nombre ?? '').split(' ').first;
    return Scaffold(
      appBar: AppBar(title: Text(nombre.isEmpty ? 'Inicio' : 'Hola, $nombre')),
      body: servicios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) {
          final enCurso = lista.where(_enCurso).toList();
          final nuevos = lista.where((s) => s.estadoAsignacion == EstadoAsignacion.asignado).length;
          if (enCurso.isEmpty) {
            return _Vacio(
              icono: Icons.route_outlined,
              titulo: 'No tienes ningún recorrido activo',
              texto: nuevos > 0
                  ? 'Tienes $nuevos ${nuevos == 1 ? 'servicio nuevo' : 'servicios nuevos'} por aceptar.'
                  : 'Cuando aceptes un servicio verás la información aquí.',
              accion: nuevos > 0 ? 'Ver disponibles' : null,
              onAccion: irADisponibles,
            );
          }
          final actual = enCurso.firstWhere((s) => s.estadoAsignacion == EstadoAsignacion.enSitio,
              orElse: () => enCurso.firstWhere((s) => s.estadoAsignacion == EstadoAsignacion.enCamino, orElse: () => enCurso.first));
          final resto = enCurso.where((s) => s.id != actual.id).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('Recorrido activo', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${enCurso.length} ${enCurso.length == 1 ? 'visita' : 'visitas'} en curso',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              _TarjetaActual(s: actual),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.alt_route),
                label: const Text('Ruta del día'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RutaOptimaScreen())),
              ),
              if (resto.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Siguientes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                for (final s in resto) ...[TarjetaServicio(s: s), const SizedBox(height: 10)],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaActual extends StatelessWidget {
  const _TarjetaActual({required this.s});
  final ServicioAsignado s;

  @override
  Widget build(BuildContext context) {
    final horario = s.horarioTexto;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Momeba.indigo,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            const Icon(Icons.navigation_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.estadoAsignacion.etiqueta.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.6, fontSize: 12.5)),
            ),
            Text(s.folio, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.clienteNombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${s.equipoTipo} ${s.marca} ${s.modelo}'.trim(), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            _Dato(icono: Icons.place_outlined, texto: s.clienteDireccion),
            if (horario != null && horario.isNotEmpty) _Dato(icono: Icons.schedule, texto: horario),
            _Dato(
                icono: s.tipoServicio == 'cargo' ? Icons.payments_outlined : Icons.verified_user_outlined,
                texto: s.tipoServicio == 'cargo' ? 'Con cargo' : 'Garantía'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalleServicioScreen(servicioId: s.id))),
              child: const Text('Continuar servicio'),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    if (texto.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, size: 17, color: Momeba.texto),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
      ]),
    );
  }
}

/// Estado vacío con ilustración sencilla (ícono en círculo tenue).
class _Vacio extends StatelessWidget {
  const _Vacio({required this.icono, required this.titulo, required this.texto, this.accion, this.onAccion});
  final IconData icono;
  final String titulo;
  final String texto;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: Momeba.turquesa.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icono, size: 56, color: Momeba.turquesaOscuro),
            ),
            const SizedBox(height: 24),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Momeba.tinta)),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Momeba.texto)),
            if (accion != null) ...[
              const SizedBox(height: 20),
              SizedBox(width: 220, child: FilledButton(onPressed: onAccion, child: Text(accion!))),
            ],
          ]),
        ),
      );
}

/* -------------------------------- Disponibles ------------------------------- */

class _DisponiblesScreen extends ConsumerWidget {
  const _DisponiblesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicios = ref.watch(serviciosAsignadosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Disponibles')),
      body: servicios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) {
          final nuevos = lista.where((s) => s.estadoAsignacion == EstadoAsignacion.asignado).toList();
          if (nuevos.isEmpty) {
            return const _Vacio(
              icono: Icons.inventory_2_outlined,
              titulo: 'No hay servicios disponibles',
              texto: 'Cuando tu coordinador te asigne uno, aparecerá aquí para que lo aceptes.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text('${nuevos.length} por aceptar', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              for (final s in nuevos) ...[TarjetaServicio(s: s), const SizedBox(height: 10)],
            ],
          );
        },
      ),
    );
  }
}

/* ----------------------------------- Más ----------------------------------- */

class _MasScreen extends ConsumerWidget {
  const _MasScreen();

  void _ir(BuildContext context, Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tecnicoActualProvider).value;
    final foto = fotoProvider(t?.selfieUrl);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: Momeba.indigo,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 20),
            child: Column(children: [
              Row(children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  backgroundImage: foto,
                  child: foto == null
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset('assets/images/momeba_simbolo.png'),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('¡Hola!', style: TextStyle(color: Colors.white70, fontSize: 15)),
                    Text(t?.nombre ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              Material(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: t == null ? null : () => _ir(context, _CredencialScreen(tecnico: t)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    child: Row(children: [
                      Icon(Icons.qr_code_2, color: Colors.white),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text('Mi credencial Grupo Momeba',
                            style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w600)),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          _Opcion(Icons.bar_chart_outlined, 'Mi productividad', () => _ir(context, const ProductividadScreen())),
          _Opcion(Icons.badge_outlined, 'Mi identificación',
              t == null ? null : () => _ir(context, _CredencialScreen(tecnico: t))),
          _Opcion(Icons.person_outline, 'Mis datos', () => _ir(context, const PerfilScreen())),
          const Divider(),
          _Opcion(Icons.alt_route, 'Ruta del día', () => _ir(context, const RutaOptimaScreen())),
          _Opcion(Icons.menu_book_outlined, 'Soporte técnico', () => _ir(context, const DescargasScreen())),
          _Opcion(Icons.ondemand_video_outlined, 'Capacitación', () => _ir(context, const CapacitacionScreen())),
          const Divider(),
          _Opcion(Icons.help_outline, 'Ayuda', () => _ayuda(context)),
          _Opcion(Icons.logout, 'Salir', () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('¿Cerrar sesión?'),
                content: const Text('Dejarás de recibir servicios en este celular hasta que vuelvas a entrar.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salir')),
                ],
              ),
            );
            if (ok == true) await cerrarSesionCompleta(ref);
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _ayuda(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Escribir a Grupo Momeba'),
            subtitle: const Text('contacto@grupomomeba.com'),
            onTap: () => launchUrl(Uri.parse('mailto:contacto@grupomomeba.com?subject=Ayuda%20app%20t%C3%A9cnicos'),
                mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Manuales y guías'),
            subtitle: const Text('Soporte técnico de tus marcas'),
            onTap: () {
              Navigator.pop(c);
              _ir(context, const DescargasScreen());
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion(this.icono, this.texto, this.onTap);
  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        minVerticalPadding: 14,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(icono, size: 26, color: Momeba.tinta),
        title: Text(texto, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500)),
        onTap: onTap,
      );
}

/* -------------------------- Credencial con QR ------------------------------ */

class _CredencialScreen extends StatelessWidget {
  const _CredencialScreen({required this.tecnico});
  final Tecnico tecnico;

  @override
  Widget build(BuildContext context) {
    final url = '${MomebaConfig.verificarTecnico}${tecnico.uid}';
    final qr = 'https://api.qrserver.com/v1/create-qr-code/?size=340x340&margin=8&data=${Uri.encodeComponent(url)}';
    final foto = fotoProvider(tecnico.selfieUrl);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi identificación')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const LogoMomeba(alto: 44),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFEDEFFA),
                backgroundImage: foto,
                child: foto == null ? const Icon(Icons.person, size: 48, color: Momeba.indigo) : null,
              ),
              const SizedBox(height: 12),
              Text(tecnico.nombre,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Pastilla('TÉCNICO DE CAMPO', color: Momeba.turquesaOscuro),
              if ((tecnico.zona ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Zona: ${tecnico.zona}', style: Theme.of(context).textTheme.bodySmall),
              ],
              if ((tecnico.placas ?? '').isNotEmpty)
                Text('Placas: ${tecnico.placas}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 18),
              Image.network(qr, width: 220, height: 220,
                  errorBuilder: (_, _, _) => const SizedBox(height: 60, child: Center(child: Text('Sin conexión para el QR')))),
              const SizedBox(height: 10),
              Text('El cliente escanea este código para confirmar que eres técnico vigente de Grupo Momeba.',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      ]),
    );
  }
}
