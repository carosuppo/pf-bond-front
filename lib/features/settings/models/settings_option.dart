import 'package:flutter/material.dart';

/// Modelo de una opción mostrada en la pantalla de configuración.
///
/// Para agregar una nueva opción a la pantalla alcanza con agregar una
/// instancia a la lista de opciones, sin modificar la lógica de renderizado.
class SettingsOption {
  const SettingsOption({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
}
