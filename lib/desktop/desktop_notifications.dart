import 'package:flutter/widgets.dart';

import 'tauri_bridge.dart';

Future<void> notifyDesktopTaskIfBackground({
  required String title,
  required String body,
}) async {
  if (!isTauriLauncherAvailable ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
    return;
  }
  try {
    await notifyDesktopTask(title: title, body: body);
  } catch (_) {
    // A missing or denied notification backend must not fail the task.
  }
}
