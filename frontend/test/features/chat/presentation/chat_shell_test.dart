import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ling/src/core/theme/app_theme.dart';
import 'package:ling/src/features/chat/presentation/chat_shell.dart';
import 'package:ling/src/shared/presentation/liquid_glass.dart';
import 'package:ling/src/shared/presentation/shared_controls.dart';

class _DismissibleOverlayHarness extends StatefulWidget {
  const _DismissibleOverlayHarness();

  @override
  State<_DismissibleOverlayHarness> createState() =>
      _DismissibleOverlayHarnessState();
}

class _DismissibleOverlayHarnessState
    extends State<_DismissibleOverlayHarness> {
  bool _isOverlayVisible = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: LingCalendarChatShell(
          conversationList: const SizedBox.expand(),
          bottomOverlay: _isOverlayVisible
              ? const ColoredBox(
                  key: Key('chat_view_overlay'),
                  color: Colors.black,
                )
              : null,
          onBottomOverlayDismissed: () {
            setState(() {
              _isOverlayVisible = false;
            });
          },
          bottomDock: const SizedBox(
            key: Key('chat_view_bottom_dock'),
            height: 80,
            child: ColoredBox(color: Colors.white),
          ),
          onAvatarTap: () {},
          onCalendarTap: () {},
          hasUnreadCalendarBadge: false,
        ),
      ),
    );
  }
}

void main() {
  Future<void> pumpChatView(
    WidgetTester tester, {
    Widget? bottomOverlay,
    VoidCallback? onBottomOverlayDismissed,
    ThemeData? theme,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: Scaffold(
          body: LingCalendarChatShell(
            conversationList: const SizedBox.expand(),
            bottomOverlay: bottomOverlay,
            onBottomOverlayDismissed: onBottomOverlayDismissed,
            bottomDock: const SizedBox(
              key: Key('chat_view_bottom_dock'),
              height: 80,
              child: ColoredBox(color: Colors.white),
            ),
            onAvatarTap: () {},
            onCalendarTap: () {},
            hasUnreadCalendarBadge: false,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpTopBar(
    WidgetTester tester, {
    required bool hasUnreadCalendarBadge,
    ThemeData? theme,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: Scaffold(
          body: LingCalendarTopBar(
            onAvatarTap: () {},
            onCalendarTap: () {},
            hasUnreadCalendarBadge: hasUnreadCalendarBadge,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders unread badge on calendar button when needed', (
    tester,
  ) async {
    await pumpTopBar(tester, hasUnreadCalendarBadge: true);

    expect(find.byKey(const Key('topbar_calendar_button')), findsOneWidget);
    expect(
      find.byKey(const Key('topbar_calendar_unread_badge')),
      findsOneWidget,
    );
  });

  testWidgets('top bar buttons use neutral light glass tint', (tester) async {
    await pumpTopBar(tester, hasUnreadCalendarBadge: false);

    final lightContext = tester.element(
      find.byKey(const Key('topbar_avatar_button')),
    );
    final lightTint = lingFloatingControlTintFor(
      lightContext,
      lightContext.palette,
    );
    final avatarButton = tester.widget<LingGlassIconButton>(
      find
          .descendant(
            of: find.byKey(const Key('topbar_avatar_button')),
            matching: find.byType(LingGlassIconButton),
          )
          .first,
    );
    final calendarButton = tester.widget<LingGlassIconButton>(
      find
          .descendant(
            of: find.byKey(const Key('topbar_calendar_button')),
            matching: find.byType(LingGlassIconButton),
          )
          .first,
    );

    expect(avatarButton.tintColor, lightTint);
    expect(calendarButton.tintColor, lightTint);
    expect(avatarButton.tintColor!.a, lessThan(0.5));
    expect(avatarButton.tintColor, isNot(lightContext.palette.accent));
    expect(avatarButton.tintColor, isNot(lightContext.palette.accentSoft));
    expect(avatarButton.tone, LingGlassSurfaceTone.control);
    expect(calendarButton.tone, LingGlassSurfaceTone.control);
    expect(avatarButton.glowColor, lightContext.palette.glassHighlight);
    expect(calendarButton.glowColor, lightContext.palette.glassHighlight);

    await pumpTopBar(
      tester,
      hasUnreadCalendarBadge: false,
      themeMode: ThemeMode.dark,
    );
    await tester.pumpAndSettle();

    final darkContext = tester.element(
      find.byKey(const Key('topbar_avatar_button')),
    );
    final darkTint = lingFloatingControlTintFor(
      darkContext,
      darkContext.palette,
    );
    final darkAvatarButton = tester.widget<LingGlassIconButton>(
      find
          .descendant(
            of: find.byKey(const Key('topbar_avatar_button')),
            matching: find.byType(LingGlassIconButton),
          )
          .first,
    );
    final darkCalendarButton = tester.widget<LingGlassIconButton>(
      find
          .descendant(
            of: find.byKey(const Key('topbar_calendar_button')),
            matching: find.byType(LingGlassIconButton),
          )
          .first,
    );

    expect(darkAvatarButton.tintColor, darkCalendarButton.tintColor);
    expect(darkAvatarButton.tintColor, darkTint);
    expect(darkAvatarButton.glowColor, darkContext.palette.glassHighlight);
  });

  testWidgets('top bar buttons reuse the same refractive style', (
    tester,
  ) async {
    await pumpTopBar(tester, hasUnreadCalendarBadge: false);

    final avatarContext = tester.element(
      find.byKey(const Key('topbar_avatar_button')),
    );
    final avatarButton = tester.widget<LingGlassIconButton>(
      find
          .descendant(
            of: find.byKey(const Key('topbar_avatar_button')),
            matching: find.byType(LingGlassIconButton),
          )
          .first,
    );
    final calendarButton = tester.widget<LingGlassIconButton>(
      find
          .descendant(
            of: find.byKey(const Key('topbar_calendar_button')),
            matching: find.byType(LingGlassIconButton),
          )
          .first,
    );
    final avatarDecorations = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.byKey(const Key('topbar_avatar_button')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>();
    final calendarDecorations = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.byKey(const Key('topbar_calendar_button')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>();
    final avatarBaseFill = avatarDecorations.firstWhere(
      (decoration) =>
          decoration.shape == BoxShape.circle && decoration.color != null,
    );
    final calendarBaseFill = calendarDecorations.firstWhere(
      (decoration) =>
          decoration.shape == BoxShape.circle && decoration.color != null,
    );

    expect(
      avatarDecorations.any((decoration) => decoration.border is Border),
      isTrue,
    );
    expect(avatarBaseFill.color, calendarBaseFill.color);
    expect(avatarButton.tintColor, calendarButton.tintColor);
    expect(
      avatarButton.tintColor,
      lingFloatingControlTintFor(avatarContext, avatarContext.palette),
    );
    expect((avatarBaseFill.color?.a ?? 1), lessThan(0.5));
    expect(
      find.byKey(const Key('floating_button_refraction_glow')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const Key('floating_button_local_backdrop')),
      findsNWidgets(2),
    );
    expect(avatarButton.useOwnLayer, isFalse);
    expect(calendarButton.useOwnLayer, isFalse);
  });

  testWidgets('hides unread badge when calendar is already read', (
    tester,
  ) async {
    await pumpTopBar(tester, hasUnreadCalendarBadge: false);

    expect(find.byKey(const Key('topbar_calendar_button')), findsOneWidget);
    expect(find.byKey(const Key('topbar_calendar_unread_badge')), findsNothing);
  });

  testWidgets('shows bottom dock when no overlay is provided', (tester) async {
    await pumpChatView(tester);

    expect(find.byKey(const Key('chat_view_bottom_dock')), findsOneWidget);
    expect(find.byKey(const Key('chat_view_overlay')), findsNothing);
  });

  testWidgets('bottom dock floats over the conversation area', (tester) async {
    await pumpChatView(tester);

    final dockRect = tester.getRect(
      find.byKey(const Key('chat_view_bottom_dock')),
    );
    final chatViewRect = tester.getRect(find.byType(LingCalendarChatShell));

    expect(dockRect.bottom, closeTo(chatViewRect.bottom, 0.1));
  });

  testWidgets('light chat shell paints a subtle white conversation backdrop', (
    tester,
  ) async {
    await pumpChatView(tester);

    final backdropFinder = find.byKey(
      const Key('chat_light_conversation_backdrop'),
    );
    expect(backdropFinder, findsOneWidget);
    expect(tester.widget<CustomPaint>(backdropFinder).painter, isNotNull);
    expect(
      tester.getRect(backdropFinder),
      tester.getRect(find.byType(LingCalendarChatShell)),
    );

    await pumpChatView(tester, themeMode: ThemeMode.dark);
    await tester.pump(const Duration(milliseconds: 250));

    expect(backdropFinder, findsNothing);
  });

  testWidgets('top conversation fade extends above controls in both themes', (
    tester,
  ) async {
    await pumpChatView(tester);

    var fadeSize = tester.getSize(
      find.byKey(const Key('chat_top_bar_conversation_fade')),
    );
    expect(fadeSize.height, LingCalendarChatShell.topBarMaskHeight);

    await pumpChatView(tester, themeMode: ThemeMode.dark);

    fadeSize = tester.getSize(
      find.byKey(const Key('chat_top_bar_conversation_fade')),
    );
    expect(fadeSize.height, LingCalendarChatShell.topBarMaskHeight);
  });

  testWidgets('renders bottom overlay above bottom dock when provided', (
    tester,
  ) async {
    await pumpChatView(
      tester,
      bottomOverlay: const ColoredBox(
        key: Key('chat_view_overlay'),
        color: Colors.black,
      ),
    );

    final overlayRect = tester.getRect(
      find.byKey(const Key('chat_view_overlay')),
    );
    final chatViewRect = tester.getRect(find.byType(LingCalendarChatShell));

    expect(find.byKey(const Key('chat_view_bottom_dock')), findsNothing);
    expect(overlayRect.bottom, closeTo(chatViewRect.bottom, 0.1));
    expect(
      overlayRect.height,
      closeTo(
        chatViewRect.height *
            LingCalendarChatShell.messageActionOverlayHeightFactor,
        1,
      ),
    );
  });

  testWidgets('dragging the bottom overlay down dismisses it', (tester) async {
    await tester.pumpWidget(const _DismissibleOverlayHarness());
    await tester.pump();

    final overlayFinder = find.byKey(const Key('chat_view_overlay'));
    expect(overlayFinder, findsOneWidget);

    final initialTop = tester.getTopLeft(overlayFinder).dy;
    final gesture = await tester.startGesture(tester.getCenter(overlayFinder));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();

    expect(tester.getTopLeft(overlayFinder).dy, greaterThan(initialTop));

    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_view_overlay')), findsNothing);
    expect(find.byKey(const Key('chat_view_bottom_dock')), findsOneWidget);
  });

  testWidgets('a short downward drag snaps the bottom overlay back', (
    tester,
  ) async {
    await tester.pumpWidget(const _DismissibleOverlayHarness());
    await tester.pump();

    final overlayFinder = find.byKey(const Key('chat_view_overlay'));
    final initialTop = tester.getTopLeft(overlayFinder).dy;

    final gesture = await tester.startGesture(tester.getCenter(overlayFinder));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();

    expect(tester.getTopLeft(overlayFinder).dy, greaterThan(initialTop));

    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_view_overlay')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('chat_view_overlay'))).dy,
      closeTo(initialTop, 0.5),
    );
  });
}
