import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const tabular = [FontFeature.tabularFigures()];

  static TextStyle money({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFeatures: tabular,
        letterSpacing: -0.2,
        decoration: decoration,
      );

  static TextStyle quantity({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFeatures: tabular,
      );
}
