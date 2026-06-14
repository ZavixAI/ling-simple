import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';

Color lingCalendarEventHeroAccentColor(
  LingPalette palette, {
  required String category,
  String status = '',
}) {
  final normalizedStatus = status.trim().toLowerCase();
  if (normalizedStatus == 'completed' || normalizedStatus == 'done') {
    return palette.success;
  }
  final normalizedCategory = category.trim().toLowerCase();
  if (normalizedCategory.contains('work') ||
      normalizedCategory.contains('meeting') ||
      normalizedCategory.contains('business') ||
      normalizedCategory.contains('工作') ||
      normalizedCategory.contains('会议')) {
    return palette.primaryButtonBackground;
  }
  if (normalizedCategory.contains('travel') ||
      normalizedCategory.contains('trip') ||
      normalizedCategory.contains('出行') ||
      normalizedCategory.contains('旅行')) {
    return palette.info;
  }
  if (normalizedCategory.contains('health') ||
      normalizedCategory.contains('健康')) {
    return palette.success;
  }
  if (normalizedCategory.contains('family') ||
      normalizedCategory.contains('personal') ||
      normalizedCategory.contains('家庭') ||
      normalizedCategory.contains('个人')) {
    return palette.warning;
  }
  return palette.info;
}

List<Color> lingCalendarEventHeroGradientColors({
  required LingPalette palette,
  required bool isDark,
  required Color accentColor,
}) {
  final base = isDark ? palette.backgroundElevated : palette.surfaceHigh;
  if (isDark) {
    return <Color>[
      Color.lerp(accentColor, base, 0.08)!,
      Color.lerp(palette.primaryButtonBackground, base, 0.28)!,
      Color.lerp(palette.background, Colors.black, 0.36)!,
    ];
  }
  return <Color>[
    Color.lerp(accentColor, base, 0.68)!,
    Color.lerp(palette.info, base, 0.76)!,
    Color.lerp(palette.surfaceMuted, const Color(0xFFE8EEF5), 0.5)!,
  ];
}
