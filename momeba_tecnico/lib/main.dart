import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:momeba_core/momeba_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/login_screen.dart';
import 'auth/seguridad_screens.dart';
import 'providers/providers.dart';
import 'services/notificaciones_locales.dart';
import 'services/rastreo_respaldo.dart';
import 'services/ubicacion_global.dart';
import 'servicios/home_tabs.dart';
import 'tema.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX'); // fechas en español
  await Firebase.initializeApp();
  await NotificacionesLocales.inicializar();
  runApp(const ProviderScope(child: MomebaApp()));
}

class MomebaApp extends StatelessWidget {
  const MomebaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Momeba Técnico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Momeba.indigo, primary: Momeba.indigo, secondary: Momeba.turquesa),
        useMaterial3: true,
      ),
      home: const _RaizApp(),
    );
  }
}

/// Decide qué pantalla mostrar: Login → técnico habilitado → Google
/// Authenticator (alta o código) → servicios.
class _RaizApp extends ConsumerStatefulWidget {
  const _RaizApp();

  @override
  ConsumerState<_RaizApp> createState() => _RaizAppState();
}

class _RaizAppState extends ConsumerState<_RaizApp> with WidgetsBindingObserver {
  Timer? _reloj;
  String? _arrancadoPara;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) => ref.read(seguridadProvider.notifier).revisarInactividad());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(seguridadProvider.notifier).alVolver();
  }

  /// Ubicación para el mapa del panel y respaldo cada 15 min (una vez por técnico).
  void _arrancarServicios(Tecnico t) {
    if (_arrancadoPara == t.uid) return;
    _arrancadoPara = t.uid;
    ServicioRepository.nombreTecnico = t.nombre;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(tecnicoRepositoryProvider);
      await repo.registrarVersion(t.uid, '1.0.0');
      await UbicacionGlobal.iniciar(t.uid, repo, nombre: t.nombre);
      await RastreoRespaldo.registrarUnaVez(t.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Alerta insistente por cada servicio recién asignado; se apaga al aceptarlo.
    ref.listen(serviciosAsignadosProvider, (previo, actual) async {
      final lista = actual.value;
      if (lista == null) return;
      UbicacionGlobal.actualizarDestinos(lista);
      for (final s in lista) {
        if (s.estadoAsignacion == EstadoAsignacion.asignado) {
          final tipo = s.tipoServicio == 'cargo' ? 'CARGO' : 'GARANTÍA';
          NotificacionesLocales.nuevoServicio(
            s.id,
            '🔔 Nuevo servicio Grupo Momeba',
            'Folio ${s.folio}: ${s.clienteNombre} · ${s.equipoTipo} ${s.marca} · $tipo. '
                'Entra y acéptalo para detener la alerta.',
          );
        } else {
          NotificacionesLocales.cancelarServicio(s.id);
        }
      }
      for (final p in previo?.value ?? const <ServicioAsignado>[]) {
        if (!lista.any((s) => s.id == p.id)) NotificacionesLocales.cancelarServicio(p.id);
      }
      // El respaldo de ubicación en segundo plano solo trabaja si hay servicios activos.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(claveServiciosActivos, lista.isNotEmpty);
      } catch (_) {}
    });

    final sesion = ref.watch(sesionProvider);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(seguridadProvider.notifier).actividad(),
      child: sesion.when(
        loading: () => const PantallaCargando(),
        error: (e, _) => PantallaMensaje(titulo: 'Error', texto: '$e'),
        data: (usuario) {
          if (usuario == null) {
            _arrancadoPara = null;
            UbicacionGlobal.detener();
            return const LoginScreen();
          }
          final tecnico = ref.watch(tecnicoActualProvider);
          return tecnico.when(
            loading: () => const PantallaCargando(),
            error: (e, _) => PantallaMensaje(
                titulo: 'No se pudo leer tu usuario', texto: '$e', accion: 'Cerrar sesión', onAccion: () => cerrarSesionCompleta(ref)),
            data: (t) {
              if (t == null || !t.habilitado) {
                return PantallaMensaje(
                  titulo: 'Sin acceso a la app',
                  texto: t == null
                      ? 'Tu cuenta no está dada de alta en Grupo Momeba. Pide al Super Admin que te registre como técnico.'
                      : !t.activo
                          ? 'Tu usuario está desactivado. Habla con tu coordinador.'
                          : 'Esta app es solo para técnicos. Usa el panel web de Grupo Momeba.',
                  accion: 'Cerrar sesión',
                  onAccion: () => cerrarSesionCompleta(ref),
                );
              }
              final gate = ref.watch(seguridadProvider);
              switch (gate.fase) {
                case FaseSeguridad.revisando:
                  return const PantallaCargando(texto: 'Verificando tu sesión…');
                case FaseSeguridad.error:
                  return PantallaMensaje(
                    titulo: 'No se pudo verificar tu sesión',
                    texto: gate.mensaje ?? '',
                    accion: 'Reintentar',
                    onAccion: () => ref.read(seguridadProvider.notifier).revisar(),
                    accion2: 'Cerrar sesión',
                    onAccion2: () => cerrarSesionCompleta(ref),
                  );
                case FaseSeguridad.alta:
                  return AltaAutenticadorScreen(alta: gate.alta!, correo: t.correo ?? '');
                case FaseSeguridad.respaldo:
                  return CodigosRespaldoScreen(codigos: gate.respaldo, correo: t.correo ?? '');
                case FaseSeguridad.codigo:
                  return CodigoScreen(aviso: gate.mensaje);
                case FaseSeguridad.lista:
                  _arrancarServicios(t);
                  return const HomeTabs();
              }
            },
          );
        },
      ),
    );
  }
}
