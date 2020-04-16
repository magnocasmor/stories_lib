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
