import 'package:flutter/material.dart';

/// Light palette from the local Figma export. Tailwind 4 colors use sRGB.
abstract final class AppColors {
  static const primary = Color(0xFF155DFC);
  static const primaryPressed = Color(0xFF1447E6);
  static const heading = Color(0xFF1C398E);
  static const background = Color(0xFFF9FAFB);
  static const surface = Colors.white;
  static const foreground = Color(0xFF0A0A0A);
  static const neutral = Color(0xFF030213);
  static const secondary = Color(0xFFEFF0F4);
  static const muted = Color(0xFFECECF0);
  static const mutedForeground = Color(0xFF717182);
  static const bodySecondary = Color(0xFF4A5565);
  static const accent = Color(0xFFE9EBEF);
  static const input = Color(0xFFF3F3F5);
  static const border = Color(0x1A000000);
  static const focus = Color(0xFFA1A1A1);
  static const destructive = Color(0xFFD4183D);
  static const blueLight = Color(0xFFEFF6FF);
  static const indigoLight = Color(0xFFE0E7FF);
  // Explicit SVG fills in ParkingMap.tsx; not Tailwind palette values.
  static const free = Color(0xFF10B981);
  static const occupied = Color(0xFFEF4444);
  static const reserved = Color(0xFFEAB308);
  static const authGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blueLight, indigoLight],
  );
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = EdgeInsets.all(lg);
}

abstract final class AppRadii {
  static const small = 6.0;
  static const control = 8.0;
  static const base = 10.0;
  static const card = 14.0;
}

abstract final class AppTypography {
  static const heading1 = TextStyle(
    fontSize: 24,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );
  static const heading2 = TextStyle(
    fontSize: 20,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );
  static const heading3 = TextStyle(
    fontSize: 18,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );
  static const title = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const small = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const button = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );
}
