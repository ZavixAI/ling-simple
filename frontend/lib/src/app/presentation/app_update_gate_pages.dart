import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class AppUpdateCheckingPage extends StatelessWidget {
  const AppUpdateCheckingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: const Center(
        child: GlassProgressIndicator.circular(
          key: Key('app_update_checking_indicator'),
          size: 28,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

class ForceUpdatePage extends StatelessWidget {
  const ForceUpdatePage({
    super.key,
    required this.strings,
    required this.onUpdate,
  });

  final LingStrings strings;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.forceUpdateTitle,
                  key: const Key('force_update_title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                LingAdaptiveFilledButton(
                  key: const Key('force_update_button'),
                  onPressed: onUpdate,
                  expand: false,
                  minHeight: 48,
                  child: Text(strings.forceUpdateAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
