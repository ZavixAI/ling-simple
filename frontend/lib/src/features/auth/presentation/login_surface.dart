import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/auth/presentation/login_visual_palettes.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';

class LingCalendarLoginSurface extends StatelessWidget {
  const LingCalendarLoginSurface({
    super.key,
    required this.hero,
    required this.currentPanel,
    required this.bottomFooter,
    this.compactVerticalSpacing = false,
  });

  final Widget hero;
  final Widget currentPanel;
  final Widget bottomFooter;
  final bool compactVerticalSpacing;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topSafeAreaInset = mediaQuery.padding.top;
    final bottomSafeAreaInset = mediaQuery.padding.bottom;
    final loginPalette = resolveLoginSurfacePalette(context);
    final overlayBase = context.isDarkMode
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return DecoratedBox(
      decoration: BoxDecoration(color: loginPalette.background),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        key: const Key('login_system_overlay'),
        value: overlayBase.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: loginPalette.background,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: Stack(
          children: [
            if (topSafeAreaInset > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topSafeAreaInset,
                child: ColoredBox(
                  key: Key('login_top_safe_area_fill'),
                  color: loginPalette.background,
                ),
              ),
            if (bottomSafeAreaInset > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomSafeAreaInset,
                child: ColoredBox(
                  key: Key('login_bottom_safe_area_fill'),
                  color: loginPalette.background,
                ),
              ),
            Positioned(
              top: -150,
              right: -80,
              child: _LoginBackgroundGlow(
                size: 400,
                color: loginPalette.primaryGlow,
              ),
            ),
            Positioned(
              bottom: -100,
              left: -40,
              child: _LoginBackgroundGlow(
                size: 350,
                color: loginPalette.secondaryGlow,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissActiveInput,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 900;
                    final isCompactPhoneWidth = constraints.maxWidth <= 390;
                    final useCompactSpacing = compactVerticalSpacing && !isWide;
                    final horizontalPadding = isWide
                        ? 56.0
                        : isCompactPhoneWidth
                        ? 32.0
                        : 40.0;
                    final verticalPadding = isWide ? 44.0 : 32.0;
                    final heroTopGap = isWide ? 72.0 : 64.0;
                    final heroPanelGap = isWide
                        ? 88.0
                        : useCompactSpacing
                        ? 36.0
                        : 56.0;
                    final scrollBottomGap = useCompactSpacing ? 12.0 : 24.0;
                    final footerGap = useCompactSpacing ? 10.0 : 16.0;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: verticalPadding),
                              child: LayoutBuilder(
                                builder: (context, scrollAreaConstraints) {
                                  final contentMinHeight = math.max(
                                    0.0,
                                    scrollAreaConstraints.maxHeight,
                                  );

                                  return SingleChildScrollView(
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: contentMinHeight,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: heroTopGap),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 520,
                                            ),
                                            child: hero,
                                          ),
                                          SizedBox(height: heroPanelGap),
                                          Align(
                                            alignment: Alignment.center,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 420,
                                              ),
                                              child: currentPanel,
                                            ),
                                          ),
                                          SizedBox(height: scrollBottomGap),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: footerGap),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: bottomFooter,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dismissActiveInput() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }
}

class LingCalendarLoginHero extends StatefulWidget {
  const LingCalendarLoginHero({
    super.key,
    required this.isZh,
    required this.title,
    required this.welcomeLead,
    required this.welcomeBrand,
    required this.tagline,
    this.showBubbles = true,
  });

  final bool isZh;
  final String title;
  final String welcomeLead;
  final String welcomeBrand;
  final String tagline;
  final bool showBubbles;

  @override
  State<LingCalendarLoginHero> createState() => _LingCalendarLoginHeroState();
}

class _LingCalendarLoginHeroState extends State<LingCalendarLoginHero>
    with SingleTickerProviderStateMixin {
  static const double _bubbleFieldHeight = 248;
  static const double _bubbleSectionHeight = 232;
  static const double _bubbleLiftOffset = -10;
  static const List<String> _zhExamples = [
    'Ling，帮我制定健身计划',
    '帮我安排明早9点的会议',
    '明天10点去机场提醒我',
    '下周安排一次团队复盘会议',
    '帮我规划一下今天的时间',
    '晚上8点提醒我给爸妈打电话',
    '这个周末有什么适合放松的活动吗',
    '帮我制定一个减脂饮食计划',
    '提醒我每周一早上开周会',
    '今天还有什么待办事项',
    '帮我总结一下今天的安排',
    '给我推荐一些专注时听的音乐',
    '帮我安排一个学习Flutter的计划',
    '下个月帮我规划一次旅行',
    '把今天的会议记录整理一下',
    '提醒我每天喝水',
    '帮我安排一个早睡计划',
    '今天下午空闲时间帮我安排点事情',
    '帮我做一个效率提升的时间表',
    '记录一下我今天的反思',
    '帮我分析一下我最近的作息',
  ];
  static const List<String> _enExamples = [
    'Ling, help me plan a workout routine',
    'Schedule my 9 AM meeting tomorrow',
    'Remind me to go to the airport at 10 AM tomorrow',
    'Plan my day for me',
    'Set a notification to call my parents tonight',
    'What should I do this weekend to relax?',
    'Create a diet plan for weight loss',
    'Remind me every Monday morning about the weekly meeting',
    'What tasks do I have today?',
    'Summarize my schedule for today',
    'Recommend some music for focus',
    'Help me learn Flutter step by step',
    'Plan a trip for next month',
    'Organize today’s meeting notes',
    'Remind me to drink water regularly',
    'Help me build a better sleep schedule',
    'Fill my free time this afternoon with something productive',
    'Create a productivity schedule for me',
    'Save today’s reflection',
    'Analyze my recent habits',
  ];

  static const Duration _bubbleLoopDuration = Duration(seconds: 14);

  late final AnimationController _bubbleController;

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: _bubbleLoopDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  List<String> get _examples => widget.isZh ? _zhExamples : _enExamples;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final loginPalette = resolveLoginSurfacePalette(context);
    final isCompactPhoneWidth = context.isCompactPhoneWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Hero(
                tag: 'logo_text',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: isCompactPhoneWidth ? 36 : 40,
                      fontWeight: FontWeight.w900,
                      color: palette.textPrimary,
                      letterSpacing: isCompactPhoneWidth ? -1.1 : -1.5,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: isCompactPhoneWidth ? 12 : 14),
            _LoginHeroLogo(size: isCompactPhoneWidth ? 64 : 72),
          ],
        ),
        SizedBox(height: isCompactPhoneWidth ? 14 : 16),
        Text(
          widget.tagline,
          style: TextStyle(
            fontSize: isCompactPhoneWidth ? 16.5 : 18,
            color: loginPalette.tagline,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        if (widget.showBubbles)
          Transform.translate(
            offset: const Offset(0, _bubbleLiftOffset),
            child: SizedBox(
              height: _bubbleSectionHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  key: const Key('login_hero_bubble_field'),
                  width: double.infinity,
                  height: _bubbleFieldHeight,
                  child: AnimatedBuilder(
                    animation: _bubbleController,
                    builder: (context, _) {
                      final elapsed =
                          _bubbleController.lastElapsedDuration ??
                          Duration.zero;
                      final globalProgress =
                          elapsed.inMilliseconds /
                          _bubbleLoopDuration.inMilliseconds;

                      return _HeroBubbleField(
                        examples: _examples,
                        globalProgress: globalProgress,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LoginHeroLogo extends StatelessWidget {
  const _LoginHeroLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = context.isDarkMode
        ? 'assets/branding/logo-transparent-dark.png'
        : 'assets/branding/logo-transparent.png';
    return IgnorePointer(
      child: Opacity(
        opacity: context.isDarkMode ? 0.82 : 0.74,
        child: Image.asset(
          asset,
          key: const Key('login_hero_logo'),
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class _HeroBubbleField extends StatelessWidget {
  const _HeroBubbleField({
    required this.examples,
    required this.globalProgress,
  });

  static const List<_HeroBubbleSpec> _bubbleSpecs = [
    _HeroBubbleSpec(
      phase: 0.00,
      swayPhase: 0.10,
      scaleBoost: 0.12,
      driftSeed: 0.18,
    ),
    _HeroBubbleSpec(
      phase: 0.34,
      swayPhase: 0.38,
      scaleBoost: 0.04,
      driftSeed: 0.44,
    ),
    _HeroBubbleSpec(
      phase: 0.68,
      swayPhase: 0.72,
      scaleBoost: 0.16,
      driftSeed: 0.67,
    ),
  ];

  final List<String> examples;
  final double globalProgress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 440.0;
          final fieldHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 210.0;
          final layouts = _buildLayouts(fieldWidth, fieldHeight)
            ..sort((a, b) => b.centerY.compareTo(a.centerY));

          return Stack(
            clipBehavior: Clip.none,
            children: [for (final layout in layouts) _buildBubble(layout)],
          );
        },
      ),
    );
  }

  List<_HeroBubbleLayout> _buildLayouts(double fieldWidth, double fieldHeight) {
    final visibleLayouts = <_HeroBubbleLayout>[];

    for (var index = 0; index < _bubbleSpecs.length; index++) {
      final layout = _createBubbleLayout(
        index,
        _bubbleSpecs[index],
        fieldWidth,
        fieldHeight,
      );
      if (layout.opacity <= 0.02) {
        continue;
      }
      visibleLayouts.add(layout);
    }

    return visibleLayouts;
  }

  _HeroBubbleLayout _createBubbleLayout(
    int index,
    _HeroBubbleSpec spec,
    double fieldWidth,
    double fieldHeight,
  ) {
    final bubbleProgress = (globalProgress + spec.phase) % 1;
    final bubbleCycle = (globalProgress + spec.phase).floor();
    final text = examples[(bubbleCycle + index) % examples.length];
    final rise = Curves.easeOutCubic.transform(bubbleProgress);
    final fadeIn = bubbleProgress < 0.18
        ? Curves.easeOut.transform(bubbleProgress / 0.18)
        : 1.0;
    final fadeOut = bubbleProgress > 0.78
        ? 1 - Curves.easeIn.transform((bubbleProgress - 0.78) / 0.22)
        : 1.0;
    final appear = fadeIn * fadeOut;
    final growth = Curves.easeOutExpo.transform(
      (bubbleProgress / 0.82).clamp(0, 1),
    );
    final baseLane = (_stableNoise(spec.driftSeed, bubbleCycle) - 0.5) * 0.72;
    final laneDrift =
        (_stableNoise(spec.driftSeed + 0.17, bubbleCycle + 1) - 0.5) * 0.26;
    final laneSwing =
        (_stableNoise(spec.driftSeed + 0.53, bubbleCycle + 2) - 0.5) * 0.18;
    final x =
        baseLane +
        laneDrift * bubbleProgress +
        math.sin((bubbleProgress + spec.swayPhase) * math.pi * 2) *
            (0.10 + laneSwing.abs()) +
        math.sin((bubbleProgress * 1.7 + spec.swayPhase * 1.3) * math.pi * 2) *
            laneSwing;
    final travel =
        1.18 + _stableNoise(spec.driftSeed + 0.29, bubbleCycle) * 0.2;
    final y = 1.04 - (rise * travel);
    final scale = 0.34 + (0.84 + spec.scaleBoost) * growth;
    final widthFactor =
        0.9 +
        Curves.easeOut.transform((bubbleProgress / 0.55).clamp(0, 1)) * 0.1;
    final width = _estimateBubbleWidth(text, scale, widthFactor);
    final height = 46.0 * scale;
    final centerX = ((x + 1) * 0.5) * fieldWidth;
    final centerY = ((y + 1) * 0.5) * fieldHeight;

    return _HeroBubbleLayout(
      text: text,
      tintIndex: (bubbleCycle + index) % 5,
      alignment: Alignment(x, y),
      opacity: appear.clamp(0, 1),
      scale: scale,
      widthFactor: widthFactor,
      width: width,
      height: height,
      centerX: centerX,
      centerY: centerY,
    );
  }

  Widget _buildBubble(_HeroBubbleLayout layout) {
    if (layout.opacity <= 0.04) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: layout.alignment,
      child: Transform.scale(
        scale: layout.scale,
        child: Transform.scale(
          scaleX: layout.widthFactor,
          child: _HeroBubbleChip(
            text: layout.text,
            opacity: layout.opacity,
            tintIndex: layout.tintIndex,
          ),
        ),
      ),
    );
  }

  static double _estimateBubbleWidth(
    String text,
    double scale,
    double widthFactor,
  ) {
    final denseTextWeight = text.contains(' ') ? 3.4 : 6.8;
    final baseWidth = (130.0 + text.length * denseTextWeight).clamp(
      160.0,
      248.0,
    );
    return baseWidth * scale * widthFactor;
  }

  static double _stableNoise(double seed, int tick) {
    final value = math.sin((tick + 1) * 12.9898 + seed * 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }
}

class _HeroBubbleChip extends StatelessWidget {
  const _HeroBubbleChip({
    required this.text,
    required this.opacity,
    required this.tintIndex,
  });

  final String text;
  final double opacity;
  final int tintIndex;

  @override
  Widget build(BuildContext context) {
    final loginPalette = resolveLoginSurfacePalette(context);
    final isDark = context.isDarkMode;
    final presence = Curves.easeOutCubic.transform(opacity);
    final baseTint =
        loginPalette.bubbleTints[tintIndex % loginPalette.bubbleTints.length];
    final tintColor = baseTint.withValues(
      alpha: (isDark ? 0.9 : 0.76) * presence,
    );
    final lightIntensity = (isDark ? 0.58 : 1.12) * presence;
    final ambientStrength = (isDark ? 0.66 : 1.02) * presence;
    return LingGlassSurface(
      key: const Key('login_hero_bubble_chip'),
      radius: 999,
      quality: LingGlassQuality.premium,
      tintColor: tintColor,
      lightIntensity: lightIntensity,
      ambientStrength: ambientStrength,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                color: loginPalette.bubbleText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBubbleSpec {
  const _HeroBubbleSpec({
    required this.phase,
    required this.swayPhase,
    required this.scaleBoost,
    required this.driftSeed,
  });

  final double phase;
  final double swayPhase;
  final double scaleBoost;
  final double driftSeed;
}

class _HeroBubbleLayout {
  const _HeroBubbleLayout({
    required this.text,
    required this.tintIndex,
    required this.alignment,
    required this.opacity,
    required this.scale,
    required this.widthFactor,
    required this.width,
    required this.height,
    required this.centerX,
    required this.centerY,
  });

  final String text;
  final int tintIndex;
  final Alignment alignment;
  final double opacity;
  final double scale;
  final double widthFactor;
  final double width;
  final double height;
  final double centerX;
  final double centerY;
}

class _LoginBackgroundGlow extends StatelessWidget {
  const _LoginBackgroundGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
