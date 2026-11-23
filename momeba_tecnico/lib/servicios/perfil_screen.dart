import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:momeba_core/momeba_core.dart';

import '../providers/providers.dart';
import '../widgets/foto_perfil.dart';

const _indigo = Color(0xFF2A2F6B);
const _verde = Color(0xFF2E7D32);
const _ambar = Color(0xFFF9A825);
const _rojo = Color(0xFFC62828);

/// 👤 Mi perfil: foto, datos básicos y el crédito de almacén vigente
/// (asignado por el administrador desde el panel — mismo dato, misma fuente).
class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  bool _subiendoFoto = false;

  Future<void> _cambiarFoto() async {
    final tecnico = ref.read(tecnicoActualProvider).value;
    if (tecnico == null) return;
    final archivo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (archivo == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final Uint8List bytes = await archivo.readAsBytes();
      final url = await ref.read(storageServiceProvider).subirFotoTecnico(tecnico.uid, 'selfie.jpg', bytes);
      await ref.read(tecnicoRepositoryProvider).actualizarSelfie(tecnico.uid, url);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('✅ Foto de perfil actualizada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir la foto: $e')));
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _editarPlacas(String? actuales) async {
    final tecnico = ref.read(tecnicoActualProvider).value;
    if (tecnico == null) return;
    final ctrl = TextEditingController(text: actuales ?? '');
    final nuevas = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Placas del vehículo'),
        content: TextField(controller: ctrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'ABC-123-D')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim().toUpperCase()), child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevas == null) return;
    try {
      await ref.read(tecnicoRepositoryProvider).actualizarPlacas(tecnico.uid, nuevas);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudieron guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tecnicoAsync = ref.watch(tecnicoActualProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: tecnicoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tecnico) {
          if (tecnico == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: const Color(0xFFEDEFFA),
                      backgroundImage: fotoProvider(tecnico.selfieUrl),
                      child: fotoProvider(tecnico.selfieUrl) == null
                          ? const Icon(Icons.person, size: 54, color: _indigo)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: _indigo,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _subiendoFoto ? null : _cambiarFoto,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _subiendoFoto
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(tecnico.nombre,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _indigo)),
              ),
              Center(
                child: Text(tecnico.correo ?? '',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7080))),
              ),
              if (tecnico.placas != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text('🚗 Placas: ${tecnico.placas}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7080))),
                ),
              ],
              const SizedBox(height: 26),
              const Text('CRÉDITO DE ALMACÉN',
                  style: TextStyle(
                      color: _indigo, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
              const SizedBox(height: 10),
              _TarjetaCreditoAlmacen(technicianId: tecnico.uid),
              const SizedBox(height: 22),
              const Text('MI ALMACÉN',
                  style: TextStyle(color: _indigo, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
              const SizedBox(height: 10),
              _MisRefacciones(technicianId: tecnico.uid),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => _editarPlacas(tecnico.placas),
                icon: const Icon(Icons.directions_car_outlined),
                label: Text(tecnico.placas == null || tecnico.placas!.isEmpty ? 'Agregar placas de mi vehículo' : 'Cambiar placas'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => cerrarSesionCompleta(ref),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaCreditoAlmacen extends StatelessWidget {
  const _TarjetaCreditoAlmacen({required this.technicianId});

  final String technicianId;

  @override
  Widget build(BuildContext context) {
    final repo = AlmacenRepository();
    return StreamBuilder<CreditoAlmacen?>(
      stream: repo.observarCreditoActivo(technicianId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final credito = snap.data;
        if (credito == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No tienes un crédito de almacén activo. Tu administrador puede asignarte uno desde el panel.',
              style: TextStyle(color: Color(0xFF6B7080), fontSize: 12.5),
            ),
          );
        }

        return FutureBuilder<double>(
          future: repo.consumoDeCredito(technicianId, credito),
          builder: (context, consumoSnap) {
            final usado = consumoSnap.data ?? 0;
            final restante = (credito.monto - usado).clamp(0, credito.monto);
            final pct = credito.monto == 0 ? 0.0 : (usado / credito.monto).clamp(0.0, 1.0);
            final color = pct >= 0.85 ? _rojo : (pct >= 0.5 ? _ambar : _verde);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6E8EF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$${credito.monto.toStringAsFixed(0)} MXN',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _indigo)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('${credito.diasRestantes} día(s) restantes',
                            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF0F1F7),
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usado: \$${usado.toStringAsFixed(2)} · Disponible: \$${restante.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7080)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Refacciones que el almacén le ha entregado al técnico (salidas).
class _MisRefacciones extends StatelessWidget {
  const _MisRefacciones({required this.technicianId});
  final String technicianId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AlmacenRepository().observarMisMovimientos(technicianId),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Text('No se pudo cargar tu almacén.', style: TextStyle(color: Color(0xFF6B7080), fontSize: 12.5));
        }
        if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
        final movs = snap.data!.where((m) => m['tipo'] == 'salida').take(20).toList();
        if (movs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(12)),
            child: const Text('Aún no tienes refacciones entregadas por el almacén.',
                style: TextStyle(color: Color(0xFF6B7080), fontSize: 12.5)),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E5F0)),
          ),
          child: Column(
            children: movs.map((m) {
              final fecha = DateTime.tryParse((m['fecha'] as String?) ?? '');
              final f = fecha == null ? '' : '${fecha.day}/${fecha.month}/${fecha.year}';
              final folio = (m['folio'] as String?) ?? '';
              return ListTile(
                dense: true,
                leading: const Icon(Icons.inventory_2_outlined, color: _indigo),
                title: Text('${m['nombre'] ?? m['sku'] ?? 'Refacción'} × ${m['cantidad'] ?? 1}'),
                subtitle: Text([f, if (folio.isNotEmpty) 'Servicio $folio'].join(' · ')),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
