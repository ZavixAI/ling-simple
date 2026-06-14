import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/models/font_size_preference.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

String settingsFontSizeTitle(LingStrings strings) {
  return strings.isZh ? '字体' : 'Text Size';
}

String settingsFontSizeLevelLabel(
  LingStrings strings,
  LingFontSizeLevel level,
) {
  return switch (level) {
    LingFontSizeLevel.small => strings.isZh ? '小' : 'Small',
    LingFontSizeLevel.mediumSmall => strings.isZh ? '中小' : 'Medium Small',
    LingFontSizeLevel.medium => strings.isZh ? '默认' : 'Default',
    LingFontSizeLevel.mediumLarge => strings.isZh ? '中大' : 'Medium Large',
    LingFontSizeLevel.large => strings.isZh ? '大' : 'Large',
  };
}

String settingsFontSizePreviewText(LingStrings strings) {
  return strings.isZh
      ? '下午三点提醒我和设计师确认本周排期。'
      : 'Remind me at 3 PM to confirm this week\'s schedule with the designer.';
}

class LingSettingsFontSizeControl extends StatelessWidget {
  const LingSettingsFontSizeControl({
    super.key,
    required this.level,
    required this.onChanged,
  });

  final LingFontSizeLevel level;
  final ValueChanged<LingFontSizeLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LingGlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      radius: 24,
      tone: LingGlassSurfaceTone.elevated,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            Text(
              'A',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: KeyedSubtree(
                key: const Key('settings_font_size_control'),
                child: LingGlassSlider(
                  value: level.storageValue.toDouble(),
                  min: 0,
                  max: (LingFontSizeLevel.values.length - 1).toDouble(),
                  divisions: LingFontSizeLevel.values.length - 1,
                  onChanged: (value) {
                    final index = value.round().clamp(
                      0,
                      LingFontSizeLevel.values.length - 1,
                    );
                    onChanged(LingFontSizeLevel.values[index]);
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'A',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LingSettingsFontSizePreview extends StatelessWidget {
  const LingSettingsFontSizePreview({
    super.key,
    required this.level,
    required this.previewText,
  });

  final LingFontSizeLevel level;
  final String previewText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LingGlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      radius: 28,
      tone: LingGlassSurfaceTone.elevated,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LingGlassSurface(
              width: 34,
              height: 34,
              radius: 999,
              tone: LingGlassSurfaceTone.accent,
              tintColor: palette.accentSoft,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: palette.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LingGlassSurface(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                radius: 24,
                tone: LingGlassSurfaceTone.muted,
                child: Text(
                  previewText,
                  key: const Key('settings_font_size_preview_text'),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: scaleLingFontSize(level, 15),
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
