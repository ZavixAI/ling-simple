import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/settings/models/settings_navigation_models.dart';
import 'package:ling/src/features/settings/presentation/settings_page_components.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/legal_documents.dart';
import 'package:ling/src/shared/presentation/surface_group.dart';

class AboutLingContent extends StatefulWidget {
  const AboutLingContent({
    super.key,
    required this.strings,
    required this.appVersion,
    required this.onOpenPage,
  });

  final LingStrings strings;
  final String appVersion;
  final ValueChanged<LingSettingsPageId> onOpenPage;

  @override
  State<AboutLingContent> createState() => _AboutLingContentState();
}

class _AboutLingContentState extends State<AboutLingContent> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _AboutLingHero(strings: widget.strings),
        const SizedBox(height: 20),
        LingSettingsRowSection(
          rows: [
            LingSettingsRootRowData(
              key: const Key('settings_about_privacy_link'),
              icon: Icons.privacy_tip_outlined,
              title: widget.strings.privacyAgreementTitle,
              subtitle: null,
              trailingLabel: null,
              onTap: () => widget.onOpenPage(LingSettingsPageId.privacy),
            ),
            LingSettingsRootRowData(
              key: const Key('settings_about_security_link'),
              icon: Icons.verified_user_outlined,
              title: widget.strings.securityAgreementTitle,
              subtitle: null,
              trailingLabel: null,
              onTap: () => widget.onOpenPage(LingSettingsPageId.security),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(height: 28),
        _AboutLingVersionText(
          label: widget.strings.appVersionLabel(widget.appVersion),
        ),
      ],
    );
  }
}

class LegalDocumentContent extends StatelessWidget {
  const LegalDocumentContent({
    super.key,
    required this.strings,
    required this.type,
  });

  final LingStrings strings;
  final LingLegalDocumentType type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            key: Key('settings_legal_document_content_${type.name}'),
            padding: lingLegalDocumentInlinePadding,
            child: LingLegalDocumentBody(
              key: Key('settings_legal_document_body_${type.name}'),
              strings: strings,
              type: type,
              useDialogPalette: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutLingHero extends StatelessWidget {
  const _AboutLingHero({required this.strings});

  final LingStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return LingSurfaceGroup(
      hasBackground: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Center(
          child: Column(
            key: const Key('settings_about_intro'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const Key('settings_about_logo'),
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: Image.asset(
                    'assets/branding/logo-circle.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: palette.accent,
                          size: 36,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                key: const Key('settings_about_introduction'),
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                child: Text(
                  strings.aboutLingIntroduction,
                  key: const Key('settings_about_introduction_text'),
                  textAlign: TextAlign.left,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textPrimary.withValues(alpha: 0.76),
                    fontFamily: 'LongCang',
                    fontSize: 22,
                    height: 1.28,
                    fontWeight: settingsPageTextWeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutLingVersionText extends StatelessWidget {
  const _AboutLingVersionText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Padding(
      key: const Key('settings_about_version_text'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Center(
        child: Text(
          label,
          key: const Key('settings_version_label'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textTertiary,
            fontSize: 12,
            fontWeight: settingsPageTextWeight,
          ),
        ),
      ),
    );
  }
}
