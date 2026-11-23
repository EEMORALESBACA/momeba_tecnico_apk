import 'package:flutter/material.dart';

/// Paleta 7 · Índigo y turquesa de Grupo Momeba.
class Momeba {
  Momeba._();
  static const indigo = Color(0xFF2A2F6B);
  static const indigoOscuro = Color(0xFF171A40);
  static const turquesa = Color(0xFF22918D);
  static const turquesaOscuro = Color(0xFF1B7A76);
  static const fondo = Color(0xFFF7F8FA);
  static const texto = Color(0xFF5A5E7A);
  static const tinta = Color(0xFF1C1F3A);
  static const linea = Color(0xFFE6E8EF);
  static const exito = Color(0xFF1F8A5B);
  static const aviso = Color(0xFFB7791F);
  static const peligro = Color(0xFFC2410C);
}

/// Tema de la app: superficies blancas, bordes finos en lugar de sombras,
/// un solo color de acción (turquesa) y texto índigo.
ThemeData temaMomeba() {
  final esquema = ColorScheme.fromSeed(seedColor: Momeba.indigo).copyWith(
    primary: Momeba.indigo,
    onPrimary: Colors.white,
    secondary: Momeba.turquesa,
    surface: Colors.white,
    onSurface: Momeba.tinta,
    outline: Momeba.linea,
    outlineVariant: Momeba.linea,
  );
  final redondo = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  final base = ThemeData(useMaterial3: true, colorScheme: esquema);
  return base.copyWith(
    scaffoldBackgroundColor: Momeba.fondo,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.apply(bodyColor: Momeba.tinta, displayColor: Momeba.tinta).copyWith(
      titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Momeba.tinta, letterSpacing: -0.2),
      titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Momeba.tinta),
      bodyMedium: const TextStyle(fontSize: 14, color: Momeba.tinta, height: 1.35),
      bodySmall: const TextStyle(fontSize: 12.5, color: Momeba.texto),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Momeba.tinta,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Momeba.tinta, letterSpacing: -0.2),
      iconTheme: IconThemeData(color: Momeba.indigo),
      actionsIconTheme: IconThemeData(color: Momeba.indigo),
      shape: Border(bottom: BorderSide(color: Momeba.linea)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Momeba.linea)),
    ),
    dividerTheme: const DividerThemeData(color: Momeba.linea, thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: Momeba.indigo, contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Momeba.turquesa,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: redondo,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Momeba.turquesa,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 48),
        shape: redondo,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Momeba.indigo,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: Momeba.linea),
        shape: redondo,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Momeba.indigo, shape: redondo)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Momeba.linea)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Momeba.linea)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Momeba.turquesa, width: 1.6)),
      labelStyle: const TextStyle(color: Momeba.texto),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      side: const BorderSide(color: Momeba.linea),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontSize: 13, color: Momeba.tinta),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: Momeba.turquesa.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Momeba.indigo : Momeba.texto)),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? Momeba.turquesaOscuro : Momeba.texto)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Momeba.tinta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Momeba.turquesa),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Momeba.turquesa, foregroundColor: Colors.white, elevation: 0),
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
  );
}

/// Etiqueta pequeña de estado (fondo tenue del color, texto del color).
class Pastilla extends StatelessWidget {
  const Pastilla(this.texto, {super.key, this.color = Momeba.indigo});
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
        child: Text(texto, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.2)),
      );
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
