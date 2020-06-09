import 'dart:math';
import 'package:flutter/material.dart';

Color stringToColor(String colorStr) {
  try {
    return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
  } catch (e) {
    return null;
  }
}

String colorToString(Color color) {
  try {
    return '#${color.value.toRadixString(16)}'.toUpperCase().replaceFirst('FF', '');
  } catch (e) {
    return null;
  }
}

double luminance(int r, int g, int b) {
  final a = [r, g, b].map((it) {
    double value = it.toDouble() / 255.0;
    return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
  }).toList();

  return a[0] * 0.2126 + a[1] * 0.7152 + a[2] * 0.0722;
}

double contrast(rgb1, rgb2) {
  return luminance(rgb2[0], rgb2[1], rgb2[2]) / luminance(rgb1[0], rgb1[1], rgb1[2]);
}
