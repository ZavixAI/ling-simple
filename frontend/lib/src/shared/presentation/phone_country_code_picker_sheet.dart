import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/shared/models/phone_country.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/tap_haptics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Future<PhoneCountry?> showPhoneCountryCodePickerSheet({
  required BuildContext context,
  required PhoneCountry selected,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.80;
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.none,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 10,
          right: 10,
          bottom:
              MediaQuery.viewInsetsOf(sheetContext).bottom +
              MediaQuery.viewPaddingOf(sheetContext).bottom +
              8,
        ),
        child: _PhoneCountryCodePickerModal(
          height: maxHeight,
          selected: selected,
        ),
      );
    },
  );
}

class _PhoneCountryCodePickerModal extends StatelessWidget {
  const _PhoneCountryCodePickerModal({
    required this.height,
    required this.selected,
  });

  final double height;
  final PhoneCountry selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      key: const Key('phone_country_code_picker_modal'),
      height: height,
      child: GlassCard(
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 28),
        settings: lingGlassSettingsFor(context, LingGlassSurfaceTone.elevated),
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textSecondary.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: PhoneCountryCodePickerSheet(selected: selected)),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoneCountryCodePickerSheet extends StatefulWidget {
  const PhoneCountryCodePickerSheet({super.key, required this.selected});

  final PhoneCountry selected;

  @override
  State<PhoneCountryCodePickerSheet> createState() =>
      _PhoneCountryCodePickerSheetState();
}

class _PhoneCountryCodePickerSheetState
    extends State<PhoneCountryCodePickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = _PhoneCountryPickerText.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LingGlassTextField(
              key: const Key('phone_country_code_search_field'),
              controller: _searchController,
              placeholder: text.searchPlaceholder,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: palette.textSecondary,
              ),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              radius: 18,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: AnimatedBuilder(
                animation: _searchController,
                builder: (context, _) {
                  final countries = [
                    for (final country in phoneCountries)
                      if (country.matches(_searchController.text)) country,
                  ];
                  if (countries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          text.emptyText,
                          key: const Key('phone_country_code_empty_text'),
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    key: const Key('phone_country_code_list'),
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                    physics: const ClampingScrollPhysics(),
                    itemCount: countries.length,
                    separatorBuilder: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: GlassDivider(
                        color: palette.outlineSoft.withValues(alpha: 0.45),
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final country = countries[index];
                      return _PhoneCountryCodeRow(
                        localeCode: text.localeCode,
                        country: country,
                        selected:
                            country.code == widget.selected.code &&
                            country.dialCode == widget.selected.dialCode,
                        onTap: () => Navigator.of(context).pop(country),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            LingGlassButton(
              key: const Key('phone_country_code_cancel_button'),
              onPressed: () => Navigator.of(context).pop(),
              minHeight: 48,
              tone: LingGlassSurfaceTone.muted,
              foregroundColor: palette.textPrimary,
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneCountryCodeRow extends StatelessWidget {
  const _PhoneCountryCodeRow({
    required this.localeCode,
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final String localeCode;
  final PhoneCountry country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selectedTint = selected
        ? palette.glassElevatedTint
        : Colors.transparent;
    return GlassInteractionSilence(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: InkWell(
          key: Key('phone_country_code_row_${country.code}'),
          onTap: LingTapHaptics.wrap(onTap),
          borderRadius: BorderRadius.circular(18),
          child: LingGlassSurface(
            constraints: const BoxConstraints(minHeight: 52),
            radius: 18,
            tone: selected
                ? LingGlassSurfaceTone.regular
                : LingGlassSurfaceTone.muted,
            tintColor: selectedTint,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    country.code,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _localizedPhoneCountryName(country, localeCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 54,
                  child: Text(
                    country.dialCode,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 22,
                          color: palette.accent,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneCountryPickerText {
  const _PhoneCountryPickerText({
    required this.localeCode,
    required this.searchPlaceholder,
    required this.emptyText,
  });

  final String localeCode;
  final String searchPlaceholder;
  final String emptyText;

  static _PhoneCountryPickerText of(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final isZh = localeCode.toLowerCase().startsWith('zh');
    return _PhoneCountryPickerText(
      localeCode: localeCode,
      searchPlaceholder: isZh ? '搜索国家/地区或区号' : 'Search country/region or code',
      emptyText: isZh ? '无匹配区号' : 'No matching country code',
    );
  }
}

String _localizedPhoneCountryName(PhoneCountry country, String localeCode) {
  if (localeCode.toLowerCase().startsWith('zh')) {
    return country.name;
  }
  return switch (country.code) {
    'CN' => 'Mainland China',
    'US' => 'United States / Canada',
    'HK' => 'Hong Kong',
    'TW' => 'Taiwan',
    'JP' => 'Japan',
    'KR' => 'South Korea',
    'SG' => 'Singapore',
    'GB' => 'United Kingdom',
    _ => country.name,
  };
}
