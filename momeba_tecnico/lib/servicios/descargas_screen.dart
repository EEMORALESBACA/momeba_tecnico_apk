import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:momeba_core/momeba_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../tema.dart';
import 'capacitacion_screen.dart';

/// Software de las marcas, explosionados y manuales que el administrador
/// publica desde el panel web (módulo Descargas). Se descargan del servidor
/// de Grupo Momeba con el navegador del celular.
class DescargasScreen extends ConsumerStatefulWidget {
  const DescargasScreen({super.key});

  @override
  ConsumerState<DescargasScreen> createState() => _DescargasScreenState();
}

class _DescargasScreenState extends ConsumerState<DescargasScreen> {
  String _busca = '';
  String _tipo = '';

  static const _tipos = {'': 'Todo', 'software': 'Software', 'explosionado': 'Explosionados', 'manual': 'Manuales', 'capacitacion': 'Capacitación', 'otro': 'Otros'};

  IconData _icono(String tipo) => switch (tipo) {
        'software' => Icons.memory,
        'explosionado' => Icons.account_tree_outlined,
        'manual' => Icons.menu_book_outlined,
        'capacitacion' => Icons.school_outlined,
        _ => Icons.insert_drive_file_outlined,
      };

  Future<void> _abrir(Descarga d) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(d.url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la descarga en este celular.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final descargas = ref.watch(descargasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Descargas'), actions: [
        IconButton(
          icon: const Icon(Icons.school_outlined),
          tooltip: 'Capacitación',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CapacitacionScreen())),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Card(
            margin: EdgeInsets.zero,
            color: Momeba.indigo,
            child: ListTile(
              leading: const Icon(Icons.school, color: Color(0xFF3FC1BB)),
              title: const Text('Capacitación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('Videos y guías para trabajar mejor', style: TextStyle(color: Color(0xFFC9CCE3))),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CapacitacionScreen())),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar marca, modelo o archivo',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _busca = v.trim().toLowerCase()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _tipos.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _tipo == e.key,
                        selectedColor: Momeba.turquesa.withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _tipo = e.key),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: descargas.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No se pudieron cargar las descargas: $e'))),
            data: (lista) {
              final f = lista.where((d) {
                if (_tipo.isNotEmpty && d.tipo != _tipo) return false;
                if (_busca.isEmpty) return true;
                return [d.titulo, d.marca, d.modelo, d.descripcion, d.nombreArchivo].whereType<String>().join(' ').toLowerCase().contains(_busca);
              }).toList();
              if (f.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      lista.isEmpty
                          ? 'Todavía no hay archivos. Tu coordinador los publica desde el panel de Grupo Momeba.'
                          : 'Nada coincide con tu búsqueda.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Momeba.texto),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: f.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = f[i];
                  final detalle = [d.tipoEtiqueta, if (d.marca != null && d.marca!.isNotEmpty) d.marca!, if (d.modelo != null && d.modelo!.isNotEmpty) d.modelo!, if (d.tamanoTexto.isNotEmpty) d.tamanoTexto]
                      .join(' · ');
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Momeba.turquesa.withValues(alpha: 0.15),
                        child: Icon(_icono(d.tipo), color: Momeba.turquesaOscuro),
                      ),
                      title: Text(d.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([detalle, if (d.descripcion != null && d.descripcion!.isNotEmpty) d.descripcion!].join('\n')),
                      isThreeLine: d.descripcion != null && d.descripcion!.isNotEmpty,
                      trailing: const Icon(Icons.download, color: Momeba.indigo),
                      onTap: () => _abrir(d),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
