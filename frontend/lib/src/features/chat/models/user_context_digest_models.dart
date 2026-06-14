class UserContextDigestDisplay {
  const UserContextDigestDisplay({
    required this.summary,
    required this.density,
    required this.starterHint,
  });

  final String summary;
  final String density;
  final UserContextDigestStarterHint starterHint;

  factory UserContextDigestDisplay.fromJson(Map<String, dynamic> json) {
    final starterHint = json['starter_hint'];
    return UserContextDigestDisplay(
      summary: (json['summary'] as String? ?? '').trim(),
      density: (json['density'] as String? ?? 'low').trim(),
      starterHint: UserContextDigestStarterHint.fromJson(
        starterHint is Map
            ? Map<String, dynamic>.from(starterHint)
            : const <String, dynamic>{},
      ),
    );
  }
}

class UserContextDigestStarterHint {
  const UserContextDigestStarterHint({
    required this.primaryTask,
    required this.hasTodayEvents,
    required this.hasNextEvent,
    required this.actionableIntentCount,
  });

  final String primaryTask;
  final bool hasTodayEvents;
  final bool hasNextEvent;
  final int actionableIntentCount;

  bool get hasActionableIdeas => actionableIntentCount > 0;

  factory UserContextDigestStarterHint.fromJson(Map<String, dynamic> json) {
    return UserContextDigestStarterHint(
      primaryTask: (json['primary_task'] as String? ?? '').trim(),
      hasTodayEvents: json['has_today_events'] == true,
      hasNextEvent: json['has_next_event'] == true,
      actionableIntentCount: _parseCount(json['actionable_intent_count']),
    );
  }

  static int _parseCount(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UserContextDigestSummary {
  const UserContextDigestSummary({
    required this.generatedAt,
    required this.timezone,
    required this.display,
  });

  final DateTime? generatedAt;
  final String timezone;
  final UserContextDigestDisplay display;

  factory UserContextDigestSummary.fromJson(Map<String, dynamic> json) {
    final display = json['display'];
    return UserContextDigestSummary(
      generatedAt: DateTime.tryParse((json['generated_at'] as String? ?? '')),
      timezone: (json['timezone'] as String? ?? '').trim(),
      display: UserContextDigestDisplay.fromJson(
        display is Map
            ? Map<String, dynamic>.from(display)
            : const <String, dynamic>{},
      ),
    );
  }
}
