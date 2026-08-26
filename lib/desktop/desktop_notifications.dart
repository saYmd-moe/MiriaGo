import 'package:flutter/widgets.dart';

import 'tauri_bridge.dart';

Future<void> notifyDesktopTaskIfBackground({
  required String title,
  required String body,
}) async {
  final lifecycleState = WidgetsBinding.instance.lifecycleState;
  if (!isTauriLauncherAvailable ||
      lifecycleState == null ||
      lifecycleState == AppLifecycleState.resumed ||
      lifecycleState == AppLifecycleState.inactive) {
    return;
  }
  try {
    await notifyDesktopTask(title: title, body: body);
  } catch (_) {
    // A missing or denied notification backend must not fail the task.
  }
}
