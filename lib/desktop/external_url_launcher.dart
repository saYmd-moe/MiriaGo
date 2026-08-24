import 'package:url_launcher/url_launcher.dart';

import 'tauri_bridge.dart';

Future<bool> launchExternalUrl(Uri uri) {
  if (isTauriLauncherAvailable) {
    return openDesktopExternalUrl(url: uri.toString());
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
