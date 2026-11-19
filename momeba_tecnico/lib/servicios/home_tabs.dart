import 'package:flutter/material.dart';

import '../tema.dart';
import 'descargas_screen.dart';
import 'lista_servicios_screen.dart';
import 'perfil_screen.dart';
import 'productividad_screen.dart';

/// Pantalla principal del técnico con cuatro pestañas:
/// Servicios, Productividad, Descargas (software y explosionados) y Perfil.
class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          ListaServiciosScreen(),
          ProductividadScreen(),
          DescargasScreen(),
          PerfilScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        indicatorColor: Momeba.turquesa.withValues(alpha: 0.18),
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.build_circle_outlined),
            selectedIcon: Icon(Icons.build_circle, color: Momeba.indigo),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights, color: Momeba.indigo),
            label: 'Productividad',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download, color: Momeba.indigo),
            label: 'Descargas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Momeba.indigo),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
