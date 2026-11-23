import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momeba_core/momeba_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../tema.dart';

/// Curso para técnicos: videos y guías que el coordinador publica en el panel
/// (Descargas, tipo "Capacitación"). Lleva el avance de cada técnico.
class CapacitacionScreen extends ConsumerWidget {
  const CapacitacionScreen({super.key});

  Future<void> _abrir(BuildContext context, WidgetRef ref, Descarga d, Tecnico? t) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(d.url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo abrir la lección en este celular.')));
      }
      return;
    }
    if (t != null && !t.capacitacion.contains(d.id)) {
      try {
        await ref.read(tecnicoRepositoryProvider).marcarLeccionVista(t.uid, d.id);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final descargas = ref.watch(descargasProvider);
    final tecnico = ref.watch(tecnicoActualProvider).value;
    final vistas = tecnico?.capacitacion ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Capacitación')),
      body: descargas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo cargar la capacitación: $e')),
        data: (todas) {
          final lecciones = todas.where((d) => d.tipo == 'capacitacion').toList()
            ..sort((a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
          if (lecciones.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay lecciones. Tu coordinador las publica desde el panel de Grupo Momeba.',
                    textAlign: TextAlign.center, style: TextStyle(color: Momeba.texto)),
              ),
            );
          }
          final hechas = lecciones.where((d) => vistas.contains(d.id)).length;
          final avance = hechas / lecciones.length;
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Momeba.indigo, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${(avance * 100).round()}% completado',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('$hechas de ${lecciones.length} lecciones vistas',
                      style: const TextStyle(color: Color(0xFFC9CCE3), fontSize: 13)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: avance,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      color: const Color(0xFF3FC1BB),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < lecciones.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: vistas.contains(lecciones[i].id) ? Momeba.turquesa : Momeba.indigo,
                      foregroundColor: Colors.white,
                      child: vistas.contains(lecciones[i].id) ? const Icon(Icons.check) : Text('${i + 1}'),
                    ),
                    title: Text(lecciones[i].titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: lecciones[i].descripcion == null || lecciones[i].descripcion!.isEmpty
                        ? null
                        : Text(lecciones[i].descripcion!),
                    trailing: const Icon(Icons.play_circle_outline, color: Momeba.indigo),
                    onTap: () => _abrir(context, ref, lecciones[i], tecnico),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
