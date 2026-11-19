import 'package:flutter/material.dart';

/// Paleta 7 · Índigo y turquesa de Grupo Momeba.
class Momeba {
  Momeba._();
  static const indigo = Color(0xFF2A2F6B);
  static const indigoOscuro = Color(0xFF171A40);
  static const turquesa = Color(0xFF22918D);
  static const turquesaOscuro = Color(0xFF1B7A76);
  static const fondo = Color(0xFFF2F3F7);
  static const texto = Color(0xFF5A5E7A);
}

/// Logotipo de Grupo Momeba con el lema, para las pantallas de acceso.
class LogoMomeba extends StatelessWidget {
  const LogoMomeba({super.key, this.alto = 74});
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/images/momeba_simbolo.png', height: alto),
      const SizedBox(height: 10),
      const Text('GRUPO MOMEBA',
          style: TextStyle(color: Momeba.indigo, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2)),
      const SizedBox(height: 4),
      const Text('PROPÓSITO SIN LÍMITES', style: TextStyle(color: Momeba.texto, fontSize: 10.5, letterSpacing: 3.5)),
    ]);
  }
}

class PantallaCargando extends StatelessWidget {
  const PantallaCargando({super.key, this.texto});
  final String? texto;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Momeba.turquesa),
            if (texto != null) ...[
              const SizedBox(height: 14),
              Text(texto!, style: const TextStyle(color: Momeba.texto)),
            ],
          ]),
        ),
      );
}

class PantallaMensaje extends StatelessWidget {
  const PantallaMensaje({
    super.key,
    required this.titulo,
    required this.texto,
    this.accion,
    this.onAccion,
    this.accion2,
    this.onAccion2,
  });
  final String titulo;
  final String texto;
  final String? accion;
  final VoidCallback? onAccion;
  final String? accion2;
  final VoidCallback? onAccion2;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const LogoMomeba(alto: 60),
                const SizedBox(height: 28),
                Text(titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Momeba.indigo)),
                const SizedBox(height: 10),
                Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Momeba.texto, fontSize: 14)),
                const SizedBox(height: 24),
                if (accion != null)
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Momeba.turquesa, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: onAccion,
                    child: Text(accion!),
                  ),
                if (accion2 != null) TextButton(onPressed: onAccion2, child: Text(accion2!)),
              ]),
            ),
          ),
        ),
      );
}
