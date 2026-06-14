import 'package:url_launcher/url_launcher.dart';

abstract interface class AppStoreLauncher {
  Future<bool> open(Uri uri);
}

class UrlLauncherAppStoreLauncher implements AppStoreLauncher {
  const UrlLauncherAppStoreLauncher();

  @override
  Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
