import 'package:ling/src/core/platform/app_platform.dart';
import 'package:ling/src/features/calendar/models/calendar_integration_models.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class CalendarProviderAppLauncher {
  Future<bool> open(CalendarProviderId provider);
}

class UrlLauncherCalendarProviderAppLauncher
    implements CalendarProviderAppLauncher {
  const UrlLauncherCalendarProviderAppLauncher();

  static const Map<CalendarProviderId, String> _providerSchemes =
      <CalendarProviderId, String>{
        CalendarProviderId.feishu: 'feishu://',
        CalendarProviderId.dingtalk: 'dingtalk://',
      };

  @override
  Future<bool> open(CalendarProviderId provider) async {
    if (AppPlatformInfo.current != AppPlatform.ios) {
      return false;
    }
    final rawScheme = _providerSchemes[provider];
    if (rawScheme == null || rawScheme.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(rawScheme);
    if (uri == null) {
      return false;
    }
    if (!await canLaunchUrl(uri)) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
