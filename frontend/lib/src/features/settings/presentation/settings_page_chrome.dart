import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/settings/presentation/settings_page_components.dart';

class SettingsPageChrome extends StatelessWidget {
  const SettingsPageChrome({
    super.key,
    required this.title,
    required this.canGoBack,
    required this.onBack,
    required this.body,
    this.trailing,
  });

  final String title;
  final bool canGoBack;
  final VoidCallback onBack;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: context.isDarkMode
          ? BoxDecoration(color: palette.background)
          : BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.backgroundElevated, palette.background],
              ),
            ),
      child: Column(
        children: [
          LingSettingsPageHeader(
            title: title,
            canGoBack: canGoBack,
            onBack: onBack,
            textWeight: settingsPageTextWeight,
            trailing: trailing,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
