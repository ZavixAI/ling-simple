enum LingFontSizeLevel {
  small,
  mediumSmall,
  medium,
  mediumLarge,
  large;

  static const LingFontSizeLevel fallback = LingFontSizeLevel.medium;

  int get storageValue => index;

  double get scaleFactor => switch (this) {
    LingFontSizeLevel.small => 0.9,
    LingFontSizeLevel.mediumSmall => 0.96,
    LingFontSizeLevel.medium => 1,
    LingFontSizeLevel.mediumLarge => 1.08,
    LingFontSizeLevel.large => 1.16,
  };
}

const String lingFontSizeLevelPreferenceKey = 'ling.font_size_level.v1';

String serializeLingFontSizeLevel(LingFontSizeLevel level) {
  return level.storageValue.toString();
}

LingFontSizeLevel? deserializeLingFontSizeLevel(String? value) {
  final parsed = int.tryParse((value ?? '').trim());
  if (parsed == null ||
      parsed < 0 ||
      parsed >= LingFontSizeLevel.values.length) {
    return null;
  }
  return LingFontSizeLevel.values[parsed];
}

double scaleLingFontSize(LingFontSizeLevel level, double baseFontSize) {
  return baseFontSize * level.scaleFactor;
}
