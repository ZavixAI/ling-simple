import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

const FontWeight _settingsMenuTextWeight = FontWeight.w400;

class LingSettingsMenuRow extends StatelessWidget {
  const LingSettingsMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.destructive = false,
    this.contentPadding,
  });

  final IconData icon;
  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool destructive;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = destructive ? palette.danger : palette.textPrimary;
    final hasSubtitle = (subtitle ?? '').trim().isNotEmpty;

    return LingGlassListTile(
      leading: leading ?? Icon(icon, color: foreground, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: foreground,
          fontSize: 16,
          fontWeight: _settingsMenuTextWeight,
        ),
      ),
      subtitle: hasSubtitle
          ? Text(
              subtitle!,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                fontWeight: _settingsMenuTextWeight,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      destructive: destructive,
      contentPadding:
          contentPadding ?? const EdgeInsets.fromLTRB(14, 13, 14, 13),
      standalone: false,
    );
  }
}
