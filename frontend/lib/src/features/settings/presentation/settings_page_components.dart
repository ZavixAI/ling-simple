import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/settings/models/account_binding_models.dart';
import 'package:ling/src/features/settings/presentation/settings_menu_row.dart';
import 'package:ling/src/shared/presentation/adaptive_controls.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/surface_group.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

const FontWeight _settingsActionTextWeight = FontWeight.w400;
const FontWeight _settingsDisclosureTextWeight = FontWeight.w400;

class LingSettingsPageHeader extends StatelessWidget {
  const LingSettingsPageHeader({
    super.key,
    required this.title,
    required this.canGoBack,
    required this.onBack,
    required this.textWeight,
    this.trailing,
  });

  final String title;
  final bool canGoBack;
  final VoidCallback onBack;
  final FontWeight textWeight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        children: [
          LingGlassIconButton(
            key: Key(
              canGoBack ? 'settings_back_button' : 'settings_close_button',
            ),
            size: 40,
            iconSize: 20,
            onPressed: LingTapHaptics.wrap(onBack),
            icon: canGoBack
                ? Icons.arrow_back_ios_new_rounded
                : Icons.close_rounded,
            iconColor: palette.textPrimary,
            tone: LingGlassSurfaceTone.control,
          ),
          Expanded(
            child: Text(
              title,
              key: const Key('settings_page_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: context.isCompactPhoneWidth ? 18 : 20,
                fontWeight: textWeight,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: trailing == null ? null : Center(child: trailing),
          ),
        ],
      ),
    );
  }
}

class LingSettingsActionButton extends StatelessWidget {
  const LingSettingsActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final minimumSize = const Size.fromHeight(52);
    final buttonChild = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: _settingsActionTextWeight,
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      child: destructive
          ? LingGlassButton(
              onPressed: onPressed,
              minHeight: minimumSize.height,
              radius: 16,
              tone: LingGlassSurfaceTone.accent,
              tintColor: backgroundColor ?? palette.destructiveButtonBackground,
              disabledTintColor:
                  (backgroundColor ?? palette.destructiveButtonBackground)
                      .withValues(alpha: 0.34),
              foregroundColor:
                  foregroundColor ?? palette.destructiveButtonForeground,
              disabledForegroundColor:
                  (foregroundColor ?? palette.destructiveButtonForeground)
                      .withValues(alpha: 0.72),
              child: buttonChild,
            )
          : LingGlassButton(
              onPressed: onPressed,
              minHeight: minimumSize.height,
              radius: 16,
              tone: LingGlassSurfaceTone.muted,
              foregroundColor: foregroundColor ?? palette.textPrimary,
              child: buttonChild,
            ),
    );
  }
}

class LingSettingsDisclosure extends StatelessWidget {
  const LingSettingsDisclosure({super.key, this.label, this.labelColor});

  final String? label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasLabel = (label ?? '').trim().isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLabel) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: labelColor ?? palette.textSecondary,
                fontSize: 12,
                fontWeight: _settingsDisclosureTextWeight,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: palette.textSecondary,
        ),
      ],
    );
  }
}

class LingSettingsGroupDivider extends StatelessWidget {
  const LingSettingsGroupDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class LingSettingsRootRowData {
  const LingSettingsRootRowData({
    this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
    this.trailing,
  });

  final Key? key;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback onTap;
  final Widget? trailing;
}

class LingSettingsRowSection extends StatelessWidget {
  const LingSettingsRowSection({super.key, required this.rows});

  final List<LingSettingsRootRowData> rows;

  @override
  Widget build(BuildContext context) {
    return LingSurfaceGroup(
      hasBackground: false,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            LingSettingsMenuRow(
              key: rows[index].key,
              icon: rows[index].icon,
              title: rows[index].title,
              subtitle: rows[index].subtitle,
              trailing:
                  rows[index].trailing ??
                  LingSettingsDisclosure(label: rows[index].trailingLabel),
              onTap: rows[index].onTap,
            ),
            if (index != rows.length - 1) const LingSettingsGroupDivider(),
          ],
        ],
      ),
    );
  }
}

class LingSettingsInlineLoading extends StatelessWidget {
  const LingSettingsInlineLoading({
    super.key,
    this.semanticLabel,
    this.size = 20,
  });

  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: GlassProgressIndicator.circular(
          size: size,
          strokeWidth: 2,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

class LingSettingsCompactDropdownRow extends StatelessWidget {
  const LingSettingsCompactDropdownRow({
    super.key,
    this.icon,
    required this.title,
    required this.dropdown,
  });

  final IconData? icon;
  final String title;
  final Widget dropdown;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = Text(
      this.title,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 16,
        fontWeight: settingsPageTextWeight,
      ),
    );
    final trailing = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: dropdown,
    );

    if (icon != null) {
      return LingGlassListTile(
        leading: Icon(icon, color: palette.textPrimary, size: 20),
        title: title,
        trailing: trailing,
        contentPadding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        standalone: false,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}

class LingSettingsSectionTitle extends StatelessWidget {
  const LingSettingsSectionTitle({
    super.key,
    required this.title,
    this.prominent = false,
  });

  final String title;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Text(
        title,
        style: TextStyle(
          color: prominent ? palette.textPrimary : palette.textSecondary,
          fontSize: prominent ? 15 : 12,
          letterSpacing: prominent ? 0 : 0.6,
          fontWeight: prominent ? settingsPageTextWeight : FontWeight.w700,
        ),
      ),
    );
  }
}

class LingSettingsBindingMethodIcon extends StatelessWidget {
  const LingSettingsBindingMethodIcon({super.key, required this.target});

  final AccountBindingTarget target;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = palette.textPrimary;

    final icon = switch (target) {
      AccountBindingTarget.phone => Icon(
        Icons.phone_iphone_rounded,
        size: 20,
        color: color,
      ),
      AccountBindingTarget.email => Icon(
        Icons.mail_outline_rounded,
        size: 20,
        color: color,
      ),
      AccountBindingTarget.apple => Icon(Icons.apple, size: 22, color: color),
      AccountBindingTarget.wechat => FaIcon(
        FontAwesomeIcons.weixin,
        size: 20,
        color: color,
      ),
    };

    return SizedBox.square(dimension: 24, child: Center(child: icon));
  }
}

/// Opens [showLingSettingsOptionSheet] on tap; looks like a normal trailing
/// value + chevron (no faux select pill).
class LingSettingsSheetPickerButton<T extends Object> extends StatelessWidget {
  const LingSettingsSheetPickerButton({
    super.key,
    this.buttonKey,
    required this.iconKey,
    required this.sheetTitle,
    required this.cancelLabel,
    required this.value,
    required this.options,
    required this.onChanged,
    this.showSheetTitle = true,
    this.showCancelButton = true,
  });

  final Key? buttonKey;
  final Key iconKey;
  final String sheetTitle;
  final String cancelLabel;
  final T value;
  final List<LingSettingsPickerOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool showSheetTitle;
  final bool showCancelButton;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selectedLabel = options
        .firstWhere((o) => o.value == value, orElse: () => options.first)
        .label;

    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: LingTapHaptics.wrap(() async {
        final next = await showLingSettingsOptionSheet<T>(
          context: context,
          title: sheetTitle,
          cancelLabel: cancelLabel,
          selected: value,
          options: options,
          showTitle: showSheetTitle,
          showCancelButton: showCancelButton,
        );
        if (next != null && context.mounted) {
          onChanged(next);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 196),
              child: Text(
                selectedLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              key: iconKey,
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration lingCalendarSettingsDropdownDecoration(
  BuildContext context, {
  String? label,
  String? helperText,
  bool compact = false,
}) {
  final palette = context.palette;
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    isDense: compact,
    filled: true,
    fillColor: palette.inputBackground,
    hintStyle: TextStyle(color: palette.inputPlaceholder),
    labelStyle: TextStyle(color: palette.inputPlaceholder),
    floatingLabelStyle: TextStyle(color: palette.inputCursor),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: palette.outlineSoft),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: palette.outlineSoft),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: palette.accent, width: 1.3),
    ),
    contentPadding: compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  );
}

const FontWeight settingsPageTextWeight = FontWeight.w400;

class LingSettingsInfoRow extends StatelessWidget {
  const LingSettingsInfoRow({
    super.key,
    required this.title,
    required this.value,
    this.textWeight = FontWeight.w400,
  });

  final String title;
  final String value;
  final FontWeight textWeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 13,
              fontWeight: textWeight,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: textWeight,
            ),
          ),
        ),
      ],
    );
  }
}
