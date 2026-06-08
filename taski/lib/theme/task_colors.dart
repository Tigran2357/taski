import 'package:flutter/material.dart';

/// 15 soft pastel shades that sit well on the app's white background.
const List<String> kTaskColors = [
  '#EF9A9A', // red
  '#F48FB1', // pink
  '#CE93D8', // purple
  '#B39DDB', // deep purple
  '#9FA8DA', // indigo
  '#90CAF9', // blue
  '#81D4FA', // light blue
  '#80DEEA', // cyan
  '#80CBC4', // teal
  '#A5D6A7', // green
  '#C5E1A5', // light green
  '#E6EE9C', // lime
  '#FFF59D', // yellow
  '#FFE082', // amber
  '#FFCC80', // orange
  '#B0BEC5', // blue grey
];

/// Brighter, saturated shades used for public (shared) folders.
const List<String> kPublicFolderColors = [
  '#ff8700',
  '#ffd300',
  '#deff0a',
  '#a1ff0a',
  '#0aff99',
  '#0aefff',
  '#147df5',
  '#580aff',
  '#be0aff',
];

/// Parses '#RRGGBB' into an opaque [Color].
Color colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

/// Readable text color (black/white) for a given background.
Color textColorOn(Color background) =>
    background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

/// Returns a darker shade of [color] by reducing its lightness by [amount]
/// (0.0–1.0). Used for borders that should read as "the darker version" of a
/// banner's background.
Color darken(Color color, [double amount = 0.3]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
