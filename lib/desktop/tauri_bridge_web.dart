import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'tauri_bridge_stub.dart'
    show
        DesktopExportDestination,
        DesktopExportSaveResult,
        DesktopLauncherInfo,
        DesktopAssetResult,
        DesktopReferenceCacheStats,
        DesktopReferenceCacheClearResult,
        DesktopRestoreImportAssetsResult,
        DesktopStateResult,
        DesktopDiagnostics,
        DesktopPlanFileSubscription;
export 'tauri_bridge_stub.dart'
    show
        DesktopExportDestination,
        DesktopExportSaveResult,
        DesktopLauncherInfo,
        DesktopAssetResult,
        DesktopReferenceCacheStats,
        DesktopReferenceCacheClearResult,
        DesktopRestoreImportAssetsResult,
        DesktopStateResult,
        DesktopDiagnostics,
        DesktopPlanFileSubscription;

class _DesktopPlanFileSubscription implements DesktopPlanFileSubscription {
  _DesktopPlanFileSubscription(this._unlisten);

  final JSFunction _unlisten;

  @override
  Future<void> dispose() async {
    _unlisten.callAsFunction();
  }
}

@JS('window')
external JSObject get _window;

bool get isTauriLauncherAvailable => _tauriCore() != null;

Future<DesktopLauncherInfo?> loadDesktopLauncherInfo() async {
  final core = _tauriCore();
  if (core == null) {
    return null;
  }

  final promise = core.callMethod<JSPromise<JSAny?>>(
    'invoke'.toJS,
    'launcher_info'.toJS,
  );
  final result = await promise.toDart;
  if (result == null || result.isUndefinedOrNull) {
    return null;
  }

  final object = result as JSObject;
  return DesktopLauncherInfo(
    appVersion: _stringProperty(object, 'appVersion') ?? '',
    platform: _stringProperty(object, 'platform') ?? '',
    portable: _boolProperty(object, 'portable') ?? false,
    fallbackUsed: _boolProperty(object, 'fallbackUsed') ?? false,
    dataDir: _stringProperty(object, 'dataDir') ?? '',
    assetsDir: _stringProperty(object, 'assetsDir') ?? '',
    exportsDir: _stringProperty(object, 'exportsDir') ?? '',
    logsDir: _stringProperty(object, 'logsDir') ?? '',
    tempDir: _stringProperty(object, 'tempDir') ?? '',
    desktopEnvironment: _stringProperty(object, 'desktopEnvironment'),
    sessionType: _stringProperty(object, 'sessionType'),
    portalUsed: _stringProperty(object, 'portalUsed') == null
        ? null
        : (_boolProperty(object, 'portalUsed') ?? false),
  );
}

Future<DesktopExportDestination?> prepareDesktopExportDestination({
  required String fileName,
  required String mimeType,
  required String extension,
}) async {
  final result = await _invokeObject('prepare_export_destination', {
    'request': {
      'fileName': fileName,
      'mimeType': mimeType,
      'extension': extension,
    },
  });
  if (result == null) {
    return null;
  }
  final action = _stringProperty(result, 'action');
  if (action == 'canceled') {
    return null;
  }
  final path = _stringProperty(result, 'path');
  if (path == null || path.isEmpty) {
    return null;
  }
  return DesktopExportDestination(path: path);
}

Future<DesktopExportSaveResult> writeDesktopExportFile({
  required String path,
  required String extension,
  required String dataBase64,
}) async {
  final result = await _invokeObject('write_export_file', {
    'request': {'path': path, 'extension': extension, 'dataBase64': dataBase64},
  });
  if (result == null) {
    throw StateError('Tauri write_export_file returned no result.');
  }
  return DesktopExportSaveResult(
    action: _stringProperty(result, 'action') ?? 'saved',
    path: _stringProperty(result, 'path'),
  );
}

Future<DesktopStateResult?> loadDesktopState() async {
  final result = await _invokeObject('load_desktop_state', const {});
  if (result == null) {
    return null;
  }
  return DesktopStateResult(
    stateJson: _stringProperty(result, 'stateJson'),
    databasePath: _stringProperty(result, 'databasePath') ?? '',
  );
}

Future<DesktopStateResult> saveDesktopState({required String stateJson}) async {
  final result = await _invokeObject('save_desktop_state', {
    'request': {'stateJson': stateJson},
  });
  if (result == null) {
    throw StateError('Tauri save_desktop_state returned no result.');
  }
  return DesktopStateResult(
    stateJson: _stringProperty(result, 'stateJson'),
    databasePath: _stringProperty(result, 'databasePath') ?? '',
  );
}

Future<DesktopStateResult> saveDesktopPlanBundle({
  required String planJson,
  required String visitRecordsJson,
  required String? activePlanId,
}) async {
  return _invokeDesktopState('save_desktop_plan_bundle', {
    'request': {
      'planJson': planJson,
      'visitRecordsJson': visitRecordsJson,
      'activePlanId': activePlanId,
    },
  });
}

Future<DesktopStateResult> deleteDesktopPlan({
  required String planId,
  required String? activePlanId,
}) async {
  return _invokeDesktopState('delete_desktop_plan', {
    'request': {'planId': planId, 'activePlanId': activePlanId},
  });
}

Future<DesktopStateResult> setDesktopActivePlan({
  required String planId,
}) async {
  return _invokeDesktopState('set_desktop_active_plan', {
    'request': {'planId': planId},
  });
}

Future<DesktopStateResult> saveDesktopSettings({
  required String settingsJson,
}) async {
  return _invokeDesktopState('save_desktop_settings', {
    'request': {'settingsJson': settingsJson},
  });
}

Future<DesktopStateResult> saveDesktopVisitRecord({
  required String recordJson,
}) async {
  return _invokeDesktopState('save_desktop_visit_record', {
    'request': {'recordJson': recordJson},
  });
}

Future<DesktopStateResult> deleteDesktopVisitRecord({
  required String recordId,
}) async {
  return _invokeDesktopState('delete_desktop_visit_record', {
    'request': {'recordId': recordId},
  });
}

Future<DesktopRestoreImportAssetsResult> restoreDesktopImportAssets({
  required String? packageId,
  required String? sourceName,
  required Map<String, String> assetsBase64,
}) async {
  final result = await _invokeObject('restore_import_assets', {
    'request': {
      'packageId': packageId,
      'sourceName': sourceName,
      'assetsBase64': assetsBase64,
    },
  });
  if (result == null) {
    throw StateError('Tauri restore_import_assets returned no result.');
  }
  final restoredPaths = <String, String>{};
  final restoredObject = result.getProperty<JSAny?>('restoredPaths'.toJS);
  if (restoredObject != null && !restoredObject.isUndefinedOrNull) {
    final entries = _objectEntries(restoredObject as JSObject).toDart;
    for (final entry in entries) {
      final pair = (entry as JSArray<JSAny?>).toDart;
      if (pair.length < 2) {
        continue;
      }
      restoredPaths[(pair[0] as JSString).toDart] =
          (pair[1] as JSString).toDart;
    }
  }
  return DesktopRestoreImportAssetsResult(restoredPaths: restoredPaths);
}

Future<DesktopAssetResult> readDesktopAsset({required String path}) async {
  final result = await _invokeObject('read_asset', {
    'request': {'path': path},
  });
  if (result == null) {
    throw StateError('Tauri read_asset returned no result.');
  }
  return DesktopAssetResult(
    dataBase64: _stringProperty(result, 'dataBase64') ?? '',
    mimeType: _stringProperty(result, 'mimeType') ?? 'application/octet-stream',
  );
}

Future<String> fetchDesktopAnitabiStaticJson({
  required String fileName,
  required String baseUrl,
  String? version,
}) async {
  final result = await _invokeObject('fetch_anitabi_static_json', {
    'request': {'fileName': fileName, 'version': version, 'baseUrl': baseUrl},
  });
  if (result == null) {
    throw StateError('Tauri fetch_anitabi_static_json returned no result.');
  }
  final body = _stringProperty(result, 'body');
  if (body == null) {
    throw StateError('Tauri fetch_anitabi_static_json returned no body.');
  }
  return body;
}

Future<bool> openDesktopExternalUrl({required String url}) {
  return _invokeBoolean('open_external_url', {
    'request': {'url': url},
  });
}

Future<DesktopPlanFileSubscription?> listenForDesktopPlanFiles(
  Future<void> Function() onQueueChanged,
) async {
  final tauri = _tauriGlobal();
  if (tauri == null) {
    return null;
  }
  final event = tauri.getProperty<JSAny?>('event'.toJS);
  if (event == null || event.isUndefinedOrNull) {
    return null;
  }
  final promise = (event as JSObject).callMethod<JSPromise<JSAny?>>(
    'listen'.toJS,
    'miriago://open-plan-file'.toJS,
    ((JSAny? rawEvent) {
      if (rawEvent == null || rawEvent.isUndefinedOrNull) {
        return;
      }
      unawaited(onQueueChanged());
    }).toJS,
  );
  final unlisten = await promise.toDart;
  if (unlisten == null || unlisten.isUndefinedOrNull) {
    return null;
  }
  return _DesktopPlanFileSubscription(unlisten as JSFunction);
}

Future<List<String>> takePendingDesktopPlanFiles() async {
  final result = await _invoke('take_pending_plan_files', const {});
  if (result == null || result.isUndefinedOrNull) {
    return const <String>[];
  }
  final values = (result as JSArray<JSAny?>).toDart;
  return values
      .whereType<JSString>()
      .map((value) => value.toDart)
      .toList(growable: false);
}

Future<DesktopDiagnostics?> loadDesktopDiagnostics() async {
  final result = await _invokeObject('desktop_diagnostics', const {});
  if (result == null) {
    return null;
  }
  return DesktopDiagnostics(text: _stringProperty(result, 'text') ?? '');
}

Future<bool> notifyDesktopTask({
  required String title,
  required String body,
}) async {
  try {
    return await _invokeBoolean('notify_desktop_task', {
      'request': {'title': title, 'body': body},
    });
  } catch (_) {
    return false;
  }
}

Future<DesktopAssetResult> writeDesktopAsset({
  required String path,
  required String dataBase64,
}) async {
  final result = await _invokeObject('write_asset', {
    'request': {'path': path, 'dataBase64': dataBase64},
  });
  if (result == null) {
    throw StateError('Tauri write_asset returned no result.');
  }
  return DesktopAssetResult(
    dataBase64: _stringProperty(result, 'dataBase64') ?? '',
    mimeType: _stringProperty(result, 'mimeType') ?? 'application/octet-stream',
  );
}

Future<DesktopReferenceCacheStats?> loadDesktopReferenceCacheStats() async {
  final result = await _invokeObject('reference_cache_stats', const {});
  if (result == null) {
    return null;
  }
  return DesktopReferenceCacheStats(
    fullBytes: _intProperty(result, 'fullBytes') ?? 0,
    fullCount: _intProperty(result, 'fullCount') ?? 0,
    thumbnailBytes: _intProperty(result, 'thumbnailBytes') ?? 0,
    thumbnailCount: _intProperty(result, 'thumbnailCount') ?? 0,
  );
}

Future<DesktopReferenceCacheClearResult?> clearDesktopReferenceCache({
  required bool includeThumbnails,
}) async {
  final result = await _invokeObject('clear_reference_cache', {
    'include_thumbnails': includeThumbnails,
  });
  if (result == null) {
    return null;
  }
  return DesktopReferenceCacheClearResult(
    fullFreedBytes: _intProperty(result, 'fullFreedBytes') ?? 0,
    fullFreedCount: _intProperty(result, 'fullFreedCount') ?? 0,
    thumbnailFreedBytes: _intProperty(result, 'thumbnailFreedBytes') ?? 0,
    thumbnailFreedCount: _intProperty(result, 'thumbnailFreedCount') ?? 0,
  );
}

Future<DesktopStateResult> _invokeDesktopState(
  String command,
  Map<String, Object?> arguments,
) async {
  final result = await _invokeObject(command, arguments);
  if (result == null) {
    throw StateError('Tauri $command returned no result.');
  }
  return DesktopStateResult(
    stateJson: _stringProperty(result, 'stateJson'),
    databasePath: _stringProperty(result, 'databasePath') ?? '',
  );
}

@JS('Object.entries')
external JSArray<JSAny?> _objectEntries(JSObject object);

Future<JSObject?> _invokeObject(
  String command,
  Map<String, Object?> arguments,
) async {
  final result = await _invoke(command, arguments);
  if (result == null || result.isUndefinedOrNull) {
    return null;
  }
  return result as JSObject;
}

Future<bool> _invokeBoolean(
  String command,
  Map<String, Object?> arguments,
) async {
  final result = await _invoke(command, arguments);
  if (result == null || result.isUndefinedOrNull) {
    return false;
  }
  return (result as JSBoolean).toDart;
}

Future<JSAny?> _invoke(String command, Map<String, Object?> arguments) async {
  final core = _tauriCore();
  if (core == null) {
    return null;
  }
  final promise = core.callMethod<JSPromise<JSAny?>>(
    'invoke'.toJS,
    command.toJS,
    _jsObjectFromMap(arguments),
  );
  return promise.toDart;
}

JSObject _jsObjectFromMap(Map<String, Object?> map) {
  final object = JSObject();
  for (final entry in map.entries) {
    object.setProperty(entry.key.toJS, _jsValue(entry.value));
  }
  return object;
}

JSObject _jsObjectFromAnyMap(Map<Object?, Object?> map) {
  final object = JSObject();
  for (final entry in map.entries) {
    final key = entry.key;
    if (key is String) {
      object.setProperty(key.toJS, _jsValue(entry.value));
    }
  }
  return object;
}

JSAny? _jsValue(Object? value) {
  if (value == null) {
    return null;
  }
  return switch (value) {
    String() => value.toJS,
    bool() => value.toJS,
    num() => value.toDouble().toJS,
    Map<String, Object?>() => _jsObjectFromMap(value),
    Map<Object?, Object?>() => _jsObjectFromAnyMap(value),
    _ => value.toString().toJS,
  };
}

JSObject? _tauriGlobal() {
  final tauri = _window.getProperty<JSAny?>('__TAURI__'.toJS);
  if (tauri == null || tauri.isUndefinedOrNull) {
    return null;
  }
  return tauri as JSObject;
}

JSObject? _tauriCore() {
  final tauri = _tauriGlobal();
  if (tauri == null || tauri.isUndefinedOrNull) {
    return null;
  }
  final core = tauri.getProperty<JSAny?>('core'.toJS);
  if (core == null || core.isUndefinedOrNull) {
    return null;
  }
  return core as JSObject;
}

String? _stringProperty(JSObject object, String name) {
  final value = object.getProperty<JSAny?>(name.toJS);
  if (value == null || value.isUndefinedOrNull) {
    return null;
  }
  return (value as JSString).toDart;
}

bool? _boolProperty(JSObject object, String name) {
  final value = object.getProperty<JSAny?>(name.toJS);
  if (value == null || value.isUndefinedOrNull) {
    return null;
  }
  return (value as JSBoolean).toDart;
}

int? _intProperty(JSObject object, String name) {
  final value = object.getProperty<JSAny?>(name.toJS);
  if (value == null || value.isUndefinedOrNull) {
    return null;
  }
  return (value as JSNumber).toDartDouble.toInt();
}
