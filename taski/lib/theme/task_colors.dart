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

/// Parses '#RRGGBB' into an opaque [Color].
Color colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}
