import 'package:flutter/material.dart';

enum PointOfInterestColor {
  red('RED', Colors.red, 'Rojo'),
  green('GREEN', Colors.green, 'Verde'),
  orange('ORANGE', Colors.orange, 'Naranja'),
  blue('BLUE', Colors.blue, 'Azul'),
  purple('PURPLE', Colors.purple, 'Púrpura'),
  grey('GREY', Colors.grey, 'Gris'),
  black('BLACK', Colors.black, 'Negro');

  const PointOfInterestColor(this.backendValue, this.visualColor, this.label);

  final String backendValue;
  final Color visualColor;
  final String label;

  static PointOfInterestColor fromBackend(Object? value) {
    for (final color in values) {
      if (color.backendValue == value) return color;
    }
    throw FormatException('Color de punto de interés inválido: $value');
  }
}
