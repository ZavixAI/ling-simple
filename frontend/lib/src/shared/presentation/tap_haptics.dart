import 'package:flutter/services.dart';

class LingTapHaptics {
  const LingTapHaptics._();

  static VoidCallback? wrap(VoidCallback? onTap) {
    if (onTap == null) {
      return null;
    }

    return () {
      HapticFeedback.selectionClick();
      onTap();
    };
  }

  static ValueChanged<T>? wrapValueChanged<T>(ValueChanged<T>? onChanged) {
    if (onChanged == null) {
      return null;
    }

    return (value) {
      HapticFeedback.selectionClick();
      onChanged(value);
    };
  }
}
