import 'package:flutter/material.dart';

class AppColors {
  static const bgTop = Color(0xFF16394A);
  static const bgBottom = Color(0xFF0A1C27);
  static const panel = Color(0xFF1C4458);
  static const panelDark = Color(0xFF0F2A38);
  static const panelEdge = Color(0xFF2F6A86);
  static const amber = Color(0xFFFFB42E);
  static const amberDark = Color(0xFFD9820B);
  static const green = Color(0xFF3ED67F);
  static const greenDark = Color(0xFF1FA55A);
  static const red = Color(0xFFFF5470);
  static const redDark = Color(0xFFC2304A);
  static const blue = Color(0xFF3E9BFF);
  static const blueDark = Color(0xFF2B6FC4);
  static const text = Colors.white;
  static const textDim = Color(0xFFA9C7D6);
  static const hidden = Color(0xFF2B3768);

  /// Tile colours (index == colour id used by the engine).
  static const tiles = <Color>[
    Color(0xFFE8333F), // 0 red
    Color(0xFF2F80FF), // 1 blue
    Color(0xFF3FD04A), // 2 green
    Color(0xFFFFD21F), // 3 yellow
    Color(0xFFB65CFF), // 4 violet
    Color(0xFFFF8B1F), // 5 orange
    Color(0xFFFF5CB1), // 6 pink
  ];

  static Color tile(int c) => tiles[c % tiles.length];

  static Color shade(Color c, double amount) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

const kFont = 'Lilita';

TextStyle gameText(double size,
    {Color color = Colors.white, double? height, double spacing = 0}) {
  return TextStyle(
    fontFamily: kFont,
    fontSize: size,
    color: color,
    height: height,
    letterSpacing: spacing,
    fontWeight: FontWeight.w400,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: kFont,
    scaffoldBackgroundColor: AppColors.bgBottom,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.amber,
      brightness: Brightness.dark,
    ),
    splashFactory: NoSplash.splashFactory,
  );
}
