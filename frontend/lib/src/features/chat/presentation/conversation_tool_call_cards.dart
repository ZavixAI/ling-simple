import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/calendar/presentation/calendar_event_hero_chrome.dart';
import 'package:ling/src/features/chat/presentation/conversation_tool_call_display.dart';
import 'package:ling/src/shared/i18n/ling_strings.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

class LingToolCallEntryCard extends StatelessWidget {
  const LingToolCallEntryCard({
    super.key,
    required this.display,
    this.onOpenLingEvent,
  });

  final LingToolCallDisplayState display;
  final ValueChanged<String>? onOpenLingEvent;

  @override
  Widget build(BuildContext context) {
    switch (display.variant) {
      case LingToolCallDisplayVariant.calendarMutation:
        final data = display.calendarData;
        final profile = display.cardProfile;
        if (data == null || profile == null) {
          return const SizedBox.shrink();
        }
        return _LingCalendarToolCallCard(
          data: data,
          profile: profile,
          onOpenLingEvent: onOpenLingEvent,
        );
      case LingToolCallDisplayVariant.travelFlightCandidates:
        final data = display.travelFlightData;
        final profile = display.cardProfile;
        if (data == null || profile == null) {
          return const SizedBox.shrink();
        }
        return _LingTravelFlightToolCallCard(data: data, profile: profile);
      case LingToolCallDisplayVariant.travelHotelCandidates:
        final data = display.travelHotelData;
        final profile = display.cardProfile;
        if (data == null || profile == null) {
          return const SizedBox.shrink();
        }
        return _LingTravelHotelToolCallCard(data: data, profile: profile);
      case LingToolCallDisplayVariant.weatherForecast:
        final data = display.weatherData;
        final profile = display.cardProfile;
        if (data == null || profile == null) {
          return const SizedBox.shrink();
        }
        return _LingWeatherToolCallCard(data: data, profile: profile);
      case LingToolCallDisplayVariant.loading:
      case LingToolCallDisplayVariant.hidden:
        return const SizedBox.shrink();
    }
  }
}

abstract class _LingToolCallCardWidget extends StatelessWidget {
  const _LingToolCallCardWidget({required this.profile});

  final LingToolCallCardProfile profile;

  bool get canOpen => profile.canOpen;
}

class _LingToolCallCardChrome extends StatelessWidget {
  const _LingToolCallCardChrome({
    required this.borderRadius,
    required this.child,
  });

  final BorderRadiusGeometry borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final background = isDark
        ? Color.lerp(palette.backgroundElevated, palette.accent, 0.035)!
        : palette.surface.withValues(alpha: 0.94);
    final borderColor = isDark
        ? palette.glassBorder.withValues(alpha: 0.28)
        : palette.outlineSoft.withValues(alpha: 0.56);
    final shadows = isDark
        ? [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.34),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: palette.accentGlow.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ]
        : const <BoxShadow>[];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

class _LingTravelFlightToolCallCard extends _LingToolCallCardWidget {
  const _LingTravelFlightToolCallCard({
    required this.data,
    required super.profile,
  });

  final LingTravelFlightToolCallData data;

  @override
  Widget build(BuildContext context) {
    final strings = _lingStringsOf(context);
    final title = strings.isZh ? '航班选项' : 'Flight options';
    final subtitle = data.subtitle.trim().isEmpty
        ? (strings.isZh
              ? '${data.flights.length} 个选项'
              : '${data.flights.length} options')
        : data.subtitle;
    return _LingCompactHorizontalToolCard(
      key: const Key('travel_flight_tool_call_card'),
      icon: Icons.flight_takeoff_rounded,
      title: title,
      subtitle: subtitle,
      itemCount: data.flights.length,
      onTap: () => _showLingToolListExpansionSheet(
        context: context,
        icon: Icons.flight_takeoff_rounded,
        title: title,
        subtitle: subtitle,
        itemCount: data.flights.length,
        expandedBuilder: (context) =>
            _LingFlightOptionsExpandedList(flights: data.flights),
      ),
      itemBuilder: (context, index) {
        final flight = data.flights[index];
        return _LingFlightOptionTile(
          index: index + 1,
          flight: flight,
          expanded: data.flights.length == 1,
        );
      },
    );
  }
}

class _LingTravelHotelToolCallCard extends _LingToolCallCardWidget {
  const _LingTravelHotelToolCallCard({
    required this.data,
    required super.profile,
  });

  final LingTravelHotelToolCallData data;

  @override
  Widget build(BuildContext context) {
    return _LingCompactHorizontalToolCard(
      key: const Key('travel_hotel_tool_call_card'),
      icon: Icons.hotel_rounded,
      title: data.title,
      subtitle: data.subtitle,
      itemCount: data.hotels.length,
      onTap: () => _showLingToolListExpansionSheet(
        context: context,
        icon: Icons.hotel_rounded,
        title: data.title,
        subtitle: data.subtitle,
        itemCount: data.hotels.length,
        expandedBuilder: (context) => _LingGenericOptionsExpandedList(
          items: [
            for (var index = 0; index < data.hotels.length; index += 1)
              _LingGenericExpandedOption(
                index: index + 1,
                title: data.hotels[index].name,
                lines: [
                  if (data.hotels[index].priceLabel.isNotEmpty)
                    data.hotels[index].priceLabel,
                  if (data.hotels[index].summary.isNotEmpty)
                    data.hotels[index].summary,
                  ...data.hotels[index].meta,
                ],
              ),
          ],
        ),
      ),
      itemBuilder: (context, index) {
        final hotel = data.hotels[index];
        return _LingTravelOptionTile(
          index: index + 1,
          title: hotel.name,
          expanded: data.hotels.length == 1,
          lines: [
            if (hotel.priceLabel.isNotEmpty) hotel.priceLabel,
            if (hotel.summary.isNotEmpty) hotel.summary,
            if (hotel.meta.isNotEmpty) hotel.meta.take(3).join(' · '),
          ],
        );
      },
    );
  }
}

class _LingWeatherToolCallCard extends _LingToolCallCardWidget {
  const _LingWeatherToolCallCard({required this.data, required super.profile});

  final LingWeatherToolCallData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = _lingStringsOf(context);
    final isZh = strings.isZh;
    final isDark = context.isDarkMode;
    final today = data.forecasts.first;
    final city = data.city.isEmpty
        ? (isZh ? '天气' : 'Weather')
        : (isZh ? '${data.city}天气' : 'Weather in ${data.city}');
    final subtitle = [
      if (data.province.isNotEmpty) data.province,
      if (data.reportTime.isNotEmpty) _compactReportTime(data.reportTime),
    ].join(' · ');
    final forecasts = data.forecasts.take(4).toList(growable: false);

    final card = _LingToolCallCardChrome(
      borderRadius: BorderRadius.circular(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 352),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.accent.withValues(alpha: isDark ? 0.18 : 0.1),
                  palette.backgroundElevated.withValues(
                    alpha: isDark ? 0.32 : 0.54,
                  ),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox(
              height: 224,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _LingWeatherIconBadge(weather: today.dayWeather),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            today.dayWeather.isEmpty
                                ? (isZh ? '天气预报' : 'Forecast')
                                : today.dayWeather,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 22,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _weatherTempRange(today),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _weatherWindLabel(today, isZh),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < forecasts.length;
                            index += 1
                          ) ...[
                            Expanded(
                              child: _LingWeatherDayTile(
                                forecast: forecasts[index],
                                isZh: isZh,
                              ),
                            ),
                            if (index != forecasts.length - 1)
                              const SizedBox(width: 7),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('weather_forecast_tool_call_card_button'),
        borderRadius: BorderRadius.circular(24),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        onTap: () => _showLingToolListExpansionSheet(
          context: context,
          icon: _weatherIcon(today.dayWeather),
          title: city,
          subtitle: subtitle,
          itemCount: data.forecasts.length,
          expandedBuilder: (context) =>
              _LingWeatherExpandedList(data: data, isZh: isZh),
        ),
        child: card,
      ),
    );
  }
}

class _LingCompactHorizontalToolCard extends StatelessWidget {
  const _LingCompactHorizontalToolCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.itemBuilder,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final accentSoft = palette.accent.withValues(alpha: isDark ? 0.18 : 0.1);
    final card = _LingToolCallCardChrome(
      borderRadius: BorderRadius.circular(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 352),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentSoft,
                  palette.backgroundElevated.withValues(
                    alpha: isDark ? 0.35 : 0.55,
                  ),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SizedBox(
              height: 238,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: palette.accent.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(icon, size: 19, color: palette.accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (subtitle.trim().isNotEmpty)
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: palette.outlineSoft.withValues(
                                alpha: 0.42,
                              ),
                            ),
                          ),
                          child: Text(
                            '$itemCount',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: itemCount == 1
                          ? itemBuilder(context, 0)
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: itemCount,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 10),
                              itemBuilder: itemBuilder,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (onTap == null) {
      return card;
    }
    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}

Future<void> _showLingToolListExpansionSheet({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required int itemCount,
  required WidgetBuilder expandedBuilder,
}) {
  final palette = context.palette;
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: palette.scrim.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 210),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LingToolListExpansionRoute(
          icon: icon,
          title: title,
          subtitle: subtitle,
          itemCount: itemCount,
          child: expandedBuilder(context),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _LingToolListExpansionRoute extends StatelessWidget {
  const _LingToolListExpansionRoute({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int itemCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final strings = _lingStringsOf(context);
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(
                  color: (isDark ? Colors.black : Colors.white).withValues(
                    alpha: isDark ? 0.36 : 0.46,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: LingGlassLayer(
                child: LingGlassSheetFrame(
                  radius: 30,
                  maxWidth: 560,
                  padding: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical -
                          24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                          child: Row(
                            children: [
                              _LingToolExpansionIcon(icon: icon),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontSize: 18,
                                        height: 1.1,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (subtitle.trim().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: palette.textSecondary,
                                            fontSize: 12.5,
                                            height: 1.1,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _LingToolExpansionCount(count: itemCount),
                              const SizedBox(width: 8),
                              Semantics(
                                button: true,
                                label: strings.isZh ? '关闭' : 'Close',
                                child: LingGlassIconButton(
                                  icon: Icons.close_rounded,
                                  size: 38,
                                  iconSize: 20,
                                  tone: LingGlassSurfaceTone.control,
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LingToolExpansionIcon extends StatelessWidget {
  const _LingToolExpansionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LingGlassSurface(
      width: 42,
      height: 42,
      radius: 15,
      padding: EdgeInsets.zero,
      tone: LingGlassSurfaceTone.elevated,
      tintColor: palette.accent.withValues(alpha: 0.13),
      child: Icon(icon, color: palette.accent, size: 22),
    );
  }
}

class _LingToolExpansionCount extends StatelessWidget {
  const _LingToolExpansionCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.outlineSoft.withValues(alpha: 0.42)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LingFlightOptionsExpandedList extends StatelessWidget {
  const _LingFlightOptionsExpandedList({required this.flights});

  final List<LingTravelFlightCandidate> flights;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < flights.length; index += 1) ...[
          _LingFlightOptionTile(
            index: index + 1,
            flight: flights[index],
            expanded: true,
          ),
          if (index != flights.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LingGenericExpandedOption {
  const _LingGenericExpandedOption({
    required this.index,
    required this.title,
    required this.lines,
  });

  final int index;
  final String title;
  final List<String> lines;
}

class _LingGenericOptionsExpandedList extends StatelessWidget {
  const _LingGenericOptionsExpandedList({required this.items});

  final List<_LingGenericExpandedOption> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index += 1) ...[
          _LingTravelOptionTile(
            index: items[index].index,
            title: items[index].title,
            lines: items[index].lines
                .where((line) => line.trim().isNotEmpty)
                .toList(growable: false),
            expanded: true,
          ),
          if (index != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LingWeatherExpandedList extends StatelessWidget {
  const _LingWeatherExpandedList({required this.data, required this.isZh});

  final LingWeatherToolCallData data;
  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final forecasts = data.forecasts;
    return Column(
      children: [
        for (var index = 0; index < forecasts.length; index += 1) ...[
          _LingWeatherExpandedDay(forecast: forecasts[index], isZh: isZh),
          if (index != forecasts.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LingWeatherExpandedDay extends StatelessWidget {
  const _LingWeatherExpandedDay({required this.forecast, required this.isZh});

  final LingWeatherForecastDay forecast;
  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    return LingGlassSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      radius: 18,
      tone: LingGlassSurfaceTone.elevated,
      tintColor: isDark
          ? palette.backgroundElevated.withValues(alpha: 0.64)
          : palette.surface.withValues(alpha: 0.76),
      child: Row(
        children: [
          _LingWeatherIconBadge(weather: forecast.dayWeather),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weatherDayLabel(forecast, isZh),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    if (forecast.dayWeather.isNotEmpty) forecast.dayWeather,
                    _weatherTempRange(forecast),
                    _weatherWindLabel(forecast, isZh),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.2,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LingTravelOptionTile extends StatelessWidget {
  const _LingTravelOptionTile({
    required this.index,
    required this.title,
    required this.lines,
    this.expanded = false,
  });

  final int index;
  final String title;
  final List<String> lines;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final content = LingGlassSurface(
      width: expanded ? null : 236,
      padding: const EdgeInsets.all(12),
      radius: 17,
      tone: LingGlassSurfaceTone.elevated,
      tintColor: isDark
          ? palette.backgroundElevated.withValues(alpha: 0.72)
          : palette.surface.withValues(alpha: 0.78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 12.8,
                    height: 1.22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final line in lines.take(3)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.4,
                      height: 1.28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
    if (!expanded) {
      return content;
    }
    return SizedBox(width: double.infinity, child: content);
  }
}

class _LingWeatherIconBadge extends StatelessWidget {
  const _LingWeatherIconBadge({required this.weather});

  final String weather;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.accent.withValues(alpha: 0.18)),
      ),
      child: Icon(_weatherIcon(weather), size: 19, color: palette.accent),
    );
  }
}

class _LingWeatherDayTile extends StatelessWidget {
  const _LingWeatherDayTile({required this.forecast, required this.isZh});

  final LingWeatherForecastDay forecast;
  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? palette.backgroundElevated.withValues(alpha: 0.42)
            : palette.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.outlineSoft.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weatherDayLabel(forecast, isZh),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textTertiary,
                fontSize: 9.8,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Icon(
              _weatherIcon(forecast.dayWeather),
              size: 16,
              color: palette.accent,
            ),
            const SizedBox(height: 5),
            Text(
              forecast.dayWeather,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10.2,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _weatherTempRange(forecast),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 10.5,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LingFlightOptionTile extends StatelessWidget {
  const _LingFlightOptionTile({
    required this.index,
    required this.flight,
    this.expanded = false,
  });

  final int index;
  final LingTravelFlightCandidate flight;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = _lingStringsOf(context);
    final isZh = strings.isZh;
    final isDark = context.isDarkMode;
    final title = [
      if (flight.airline.isNotEmpty) flight.airline,
      if (flight.flightNo.isNotEmpty) flight.flightNo,
    ].join(' ');
    final fallbackTitle = title.isEmpty ? flight.summary : title;
    final meta = [
      if (flight.durationLabel.isNotEmpty)
        _localizedFlightDuration(flight.durationLabel, isZh),
    ];
    final cabin = flight.cabinLabels.isNotEmpty
        ? _localizedCabinLabel(flight.cabinLabels.first, isZh)
        : '';
    final price = _localizedFlightPriceLabel(flight.priceLabel, isZh);
    final aircraft = _localizedAircraftLabel(flight.aircraftLabel, isZh);
    final content = LingGlassSurface(
      width: expanded ? null : 236,
      padding: const EdgeInsets.all(12),
      radius: 17,
      tone: LingGlassSurfaceTone.elevated,
      tintColor: isDark
          ? palette.backgroundElevated.withValues(alpha: 0.72)
          : palette.surface.withValues(alpha: 0.78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fallbackTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LingFlightTimeColumn(
                time: flight.departureTime,
                label: isZh ? '出发' : 'Depart',
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.east_rounded,
                        size: 18,
                        color: palette.accent.withValues(alpha: 0.78),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.textTertiary,
                            fontSize: 9.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _LingFlightTimeColumn(
                time: flight.arrivalTime,
                label: isZh ? '到达' : 'Arrive',
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: 9),
          _LingFlightRouteLine(route: flight.routeLabel, aircraft: aircraft),
          const SizedBox(height: 9),
          Row(
            children: [
              if (cabin.isNotEmpty)
                Expanded(
                  child: _LingTravelChip(
                    icon: Icons.airline_seat_recline_normal_rounded,
                    label: cabin,
                    maxWidth: double.infinity,
                  ),
                ),
              if (cabin.isNotEmpty && (price.isNotEmpty || meta.isNotEmpty))
                const SizedBox(width: 6),
              if (price.isNotEmpty)
                Expanded(
                  child: _LingTravelChip(
                    icon: Icons.payments_rounded,
                    label: price,
                    maxWidth: double.infinity,
                  ),
                )
              else if (meta.isNotEmpty)
                Expanded(
                  child: _LingTravelChip(
                    icon: Icons.schedule_rounded,
                    label: meta.first,
                    maxWidth: double.infinity,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    if (!expanded) {
      return content;
    }
    return SizedBox(width: double.infinity, child: content);
  }
}

class _LingFlightRouteLine extends StatelessWidget {
  const _LingFlightRouteLine({required this.route, required this.aircraft});

  final String route;
  final String aircraft;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasRoute = route.trim().isNotEmpty;
    final hasAircraft = aircraft.trim().isNotEmpty;
    if (!hasRoute && !hasAircraft) {
      return const SizedBox(height: 17);
    }
    return SizedBox(
      height: 17,
      child: Row(
        children: [
          if (hasRoute) ...[
            Icon(
              Icons.route_rounded,
              size: 13,
              color: palette.accent.withValues(alpha: 0.78),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                route,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 10.7,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (hasAircraft) ...[
            const SizedBox(width: 6),
            Flexible(
              flex: 0,
              child: Text(
                aircraft,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textTertiary,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LingFlightTimeColumn extends StatelessWidget {
  const _LingFlightTimeColumn({
    required this.time,
    required this.label,
    this.alignEnd = false,
  });

  final String time;
  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 58,
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            time.isEmpty ? '--:--' : time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textTertiary,
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LingTravelChip extends StatelessWidget {
  const _LingTravelChip({
    required this.icon,
    required this.label,
    this.maxWidth = 112,
  });

  final IconData icon;
  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (label.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 10.4,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _localizedFlightDuration(String value, bool isZh) {
  if (!isZh) {
    return value;
  }
  return value.replaceAll('h', '小时').replaceAll('m', '分');
}

String _localizedFlightPriceLabel(String value, bool isZh) {
  if (value.isEmpty) {
    return '';
  }
  return isZh ? '$value 起' : 'from $value';
}

String _localizedAircraftLabel(String value, bool isZh) {
  if (value.isEmpty) {
    return '';
  }
  return isZh ? '机型 $value' : 'Aircraft $value';
}

String _localizedCabinLabel(String value, bool isZh) {
  if (isZh) {
    return value;
  }
  return value
      .replaceAll('高端经济舱', 'Premium Economy')
      .replaceAll('豪华经济舱', 'Premium Economy')
      .replaceAll('经济舱', 'Economy')
      .replaceAll('商务舱', 'Business')
      .replaceAll('头等舱', 'First');
}

IconData _weatherIcon(String weather) {
  if (weather.contains('雷')) {
    return Icons.thunderstorm_rounded;
  }
  if (weather.contains('雨')) {
    return Icons.water_drop_rounded;
  }
  if (weather.contains('雪')) {
    return Icons.ac_unit_rounded;
  }
  if (weather.contains('晴')) {
    return Icons.wb_sunny_rounded;
  }
  if (weather.contains('云') || weather.contains('阴')) {
    return Icons.cloud_rounded;
  }
  return Icons.thermostat_rounded;
}

String _compactReportTime(String value) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})',
  ).firstMatch(value);
  if (match == null) {
    return value;
  }
  return '${match.group(1)} ${match.group(2)}';
}

String _weatherDayLabel(LingWeatherForecastDay forecast, bool isZh) {
  if (isZh) {
    final week = switch (forecast.week) {
      '1' => '周一',
      '2' => '周二',
      '3' => '周三',
      '4' => '周四',
      '5' => '周五',
      '6' => '周六',
      '7' => '周日',
      _ => '',
    };
    return week.isEmpty ? _shortWeatherDate(forecast.date) : week;
  }
  final week = switch (forecast.week) {
    '1' => 'Mon',
    '2' => 'Tue',
    '3' => 'Wed',
    '4' => 'Thu',
    '5' => 'Fri',
    '6' => 'Sat',
    '7' => 'Sun',
    _ => '',
  };
  return week.isEmpty ? _shortWeatherDate(forecast.date) : week;
}

String _shortWeatherDate(String value) {
  final match = RegExp(r'^\d{4}-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return value;
  }
  return '${match.group(1)}-${match.group(2)}';
}

String _weatherTempRange(LingWeatherForecastDay forecast) {
  final low = forecast.nightTemp;
  final high = forecast.dayTemp;
  if (low.isEmpty && high.isEmpty) {
    return '--°';
  }
  if (low.isEmpty) {
    return '$high°';
  }
  if (high.isEmpty) {
    return '$low°';
  }
  return '$low°-$high°';
}

String _weatherWindLabel(LingWeatherForecastDay forecast, bool isZh) {
  final wind = forecast.dayWind.isEmpty
      ? ''
      : (isZh ? '${forecast.dayWind}风' : '${forecast.dayWind} wind');
  final power = forecast.dayPower.isEmpty
      ? ''
      : (isZh ? '${forecast.dayPower}级' : forecast.dayPower);
  final label = [wind, power].where((item) => item.isNotEmpty).join(' ');
  if (label.isEmpty) {
    return isZh ? '风力暂无' : 'Wind unavailable';
  }
  return isZh ? '风力 $label' : 'Wind $label';
}

String _calendarSummaryLabel(
  LingStrings strings,
  LingCalendarToolCallData data,
) {
  if (data.isDelete) {
    return strings.calendarToolCallDeleted;
  }
  if (data.isComplete) {
    return strings.calendarToolCallCompleted;
  }
  if (data.isCreate) {
    return strings.calendarToolCallCreated;
  }
  return strings.calendarToolCallUpdated;
}

Color _calendarStatusAccentColor(
  LingPalette palette,
  LingCalendarToolCallData data,
) {
  if (data.isDelete) {
    return palette.danger;
  }
  if (data.isComplete) {
    return palette.success;
  }
  return palette.accent;
}

String _calendarMonthLabel(int month) {
  const labels = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  if (month < 1 || month > labels.length) {
    return 'CAL';
  }
  return labels[month - 1];
}

class _LingToolCallStatusMark extends StatelessWidget {
  const _LingToolCallStatusMark({
    required this.icon,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: compact ? 20 : 22,
        height: compact ? 20 : 22,
        child: Icon(icon, size: compact ? 13 : 14, color: Colors.white),
      ),
    );
  }
}

class _LingCalendarToolCallCard extends _LingToolCallCardWidget {
  const _LingCalendarToolCallCard({
    required this.data,
    required super.profile,
    this.onOpenLingEvent,
  });

  final LingCalendarToolCallData data;
  final ValueChanged<String>? onOpenLingEvent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = _lingStringsOf(context);
    final summaryLabel = _calendarSummaryLabel(strings, data);
    final accentColor = _calendarStatusAccentColor(palette, data);
    final backdropAccentColor = lingCalendarEventHeroAccentColor(
      palette,
      category: data.category,
    );
    final title = data.title.trim().isEmpty
        ? strings.calendarToolCallDeletedFallbackTitle
        : data.title;
    final timeLabel = _formatLingCalendarTimeLabel(
      context: context,
      startAt: data.startAt,
      endAt: data.endAt,
      timeShape: data.timeShape,
    );
    final categoryLabel = strings.calendarToolCallCategoryLabel(data.category);
    final location = data.location.trim();
    final onTap = !canOpen || onOpenLingEvent == null
        ? null
        : () => onOpenLingEvent!(data.eventId);
    final startParts = _LingCalendarIsoParts.tryParse(data.startAt);
    final dateLabel = startParts == null
        ? timeLabel
        : startParts.formatDate(isChinese: strings.isZh);
    const cardHeight = 224.0;
    final heroTag = _calendarEventHeroTag(data.eventId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('calendar_tool_call_card'),
        borderRadius: BorderRadius.circular(32),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
        onTap: onTap,
        child: _LingToolCallCardChrome(
          borderRadius: BorderRadius.circular(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 352),
            child: Hero(
              tag: heroTag,
              flightShuttleBuilder:
                  (context, animation, direction, fromContext, toContext) {
                    return Material(
                      color: Colors.transparent,
                      child: direction == HeroFlightDirection.push
                          ? toContext.widget
                          : fromContext.widget,
                    );
                  },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: SizedBox(
                  height: cardHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _LingCalendarThumbnailBackdrop(
                        accentColor: backdropAccentColor,
                        startParts: startParts,
                      ),
                      Positioned(
                        left: 16,
                        top: 16,
                        right: 16,
                        child: _LingCalendarThumbnailTopBar(
                          summaryLabel: summaryLabel,
                          accentColor: accentColor,
                          isDelete: data.isDelete,
                          onTapEnabled: onTap != null,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _LingCalendarThumbnailOverlay(
                          title: title,
                          isDelete: data.isDelete,
                          dateLabel: dateLabel,
                          timeLabel: timeLabel,
                          categoryLabel: categoryLabel,
                          location: location,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LingCalendarThumbnailBackdrop extends StatelessWidget {
  const _LingCalendarThumbnailBackdrop({
    required this.accentColor,
    required this.startParts,
  });

  final Color accentColor;
  final _LingCalendarIsoParts? startParts;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final dateLabel = startParts == null
        ? '--'
        : startParts!.day.toString().padLeft(2, '0');
    final monthLabel = startParts == null
        ? 'CAL'
        : _calendarMonthLabel(startParts!.month);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: lingCalendarEventHeroGradientColors(
            palette: palette,
            isDark: isDark,
            accentColor: accentColor,
          ),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -34,
            right: -30,
            child: Icon(
              Icons.calendar_month_rounded,
              size: 188,
              color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.16),
            ),
          ),
          Positioned(
            left: 20,
            top: 62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.22),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.28),
                ),
              ),
              child: SizedBox(
                width: 96,
                height: 96,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      monthLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: isDark ? 0.56 : 0.42),
                  ],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LingCalendarThumbnailTopBar extends StatelessWidget {
  const _LingCalendarThumbnailTopBar({
    required this.summaryLabel,
    required this.accentColor,
    required this.isDelete,
    required this.onTapEnabled,
  });

  final String summaryLabel;
  final Color accentColor;
  final bool isDelete;
  final bool onTapEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LingToolCallStatusMark(
                      icon: isDelete
                          ? Icons.delete_outline_rounded
                          : Icons.event_available_outlined,
                      color: accentColor,
                      compact: !isDelete,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        summaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onTapEnabled) ...[
          const SizedBox(width: 8),
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 34,
                height: 34,
                color: Colors.black.withValues(alpha: 0.34),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LingCalendarThumbnailOverlay extends StatelessWidget {
  const _LingCalendarThumbnailOverlay({
    required this.title,
    required this.isDelete,
    required this.dateLabel,
    required this.timeLabel,
    required this.categoryLabel,
    required this.location,
  });

  final String title;
  final bool isDelete;
  final String dateLabel;
  final String timeLabel;
  final String categoryLabel;
  final String location;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.66),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 30, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                      fontFamily: 'Plus Jakarta Sans',
                    ).copyWith(
                      decoration: isDelete ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white.withValues(alpha: 0.9),
                      decorationThickness: 2,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ).copyWith(
                      decoration: isDelete ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white.withValues(alpha: 0.8),
                      decorationThickness: 1.8,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LingCalendarOverlayChip(
                    icon: Icons.schedule_rounded,
                    label: timeLabel,
                    isStruck: isDelete,
                  ),
                  _LingCalendarOverlayChip(
                    icon: Icons.sell_outlined,
                    label: categoryLabel,
                    isStruck: isDelete,
                  ),
                  if (location.isNotEmpty)
                    _LingCalendarOverlayChip(
                      icon: Icons.place_outlined,
                      label: location,
                      isStruck: isDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _calendarEventHeroTag(String eventId) {
  return 'ling_calendar_event_${eventId.trim()}';
}

class _LingCalendarOverlayChip extends StatelessWidget {
  const _LingCalendarOverlayChip({
    required this.icon,
    required this.label,
    this.isStruck = false,
  });

  final IconData icon;
  final String label;
  final bool isStruck;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 286),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.78)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ).copyWith(
                    decoration: isStruck ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white.withValues(alpha: 0.82),
                    decorationThickness: 1.7,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatLingCalendarTimeLabel({
  required BuildContext context,
  required String startAt,
  required String endAt,
  required String timeShape,
}) {
  final strings = _lingStringsOf(context);
  final start = _LingCalendarIsoParts.tryParse(startAt);
  final end = _LingCalendarIsoParts.tryParse(endAt);
  if (start == null && end == null) {
    return '';
  }
  if (start == null) {
    return end!.format(isChinese: strings.isZh);
  }
  if (end == null) {
    return start.format(isChinese: strings.isZh);
  }
  final isChinese = strings.isZh;
  final startDateLabel = start.formatDate(isChinese: isChinese);
  final endDateLabel = end.formatDate(isChinese: isChinese);
  final startTimeLabel = start.formatTime();
  final endTimeLabel = end.formatTime();
  if (_isPointCalendarToolCallTime(
    start: start,
    end: end,
    timeShape: timeShape,
  )) {
    return startDateLabel == endDateLabel
        ? startTimeLabel
        : start.format(isChinese: isChinese);
  }
  if (startDateLabel == endDateLabel) {
    return '$startDateLabel $startTimeLabel - $endTimeLabel';
  }
  return '$startDateLabel $startTimeLabel - $endDateLabel $endTimeLabel';
}

bool _isPointCalendarToolCallTime({
  required _LingCalendarIsoParts start,
  required _LingCalendarIsoParts end,
  required String timeShape,
}) {
  if (timeShape.trim().toLowerCase() == 'point') {
    return true;
  }
  return start.hasSameMinute(end);
}

class _LingCalendarIsoParts {
  const _LingCalendarIsoParts({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
  });

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  static _LingCalendarIsoParts? tryParse(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})',
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    return _LingCalendarIsoParts(
      year: int.parse(match.group(1)!),
      month: int.parse(match.group(2)!),
      day: int.parse(match.group(3)!),
      hour: int.parse(match.group(4)!),
      minute: int.parse(match.group(5)!),
    );
  }

  String format({required bool isChinese}) {
    final dateLabel = formatDate(isChinese: isChinese);
    return '$dateLabel ${formatTime()}';
  }

  String formatDate({required bool isChinese}) {
    if (isChinese) {
      return '$month月$day日';
    }
    return '$month/$day/$year';
  }

  String formatTime() {
    final minuteLabel = minute.toString().padLeft(2, '0');
    return '$hour:$minuteLabel';
  }

  bool hasSameMinute(_LingCalendarIsoParts other) {
    return year == other.year &&
        month == other.month &&
        day == other.day &&
        hour == other.hour &&
        minute == other.minute;
  }
}

LingStrings _lingStringsOf(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final countryCode = locale.countryCode;
  final localeCode = countryCode == null || countryCode.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}-$countryCode';
  return LingStrings(localeCode);
}
