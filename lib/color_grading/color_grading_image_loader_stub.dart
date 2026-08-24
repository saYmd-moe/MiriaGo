import 'dart:convert';

import 'package:flutter/services.dart';

import '../desktop/desktop_asset_image.dart';
import '../desktop/tauri_bridge.dart' as tauri;

Future<Uint8List?> loadColorGradingImageBytes(String path) async {
  final value = path.trim();
  if (value.isEmpty) {
    return null;
  }

  if (value.startsWith('docs/sample_images/')) {
    final data = await rootBundle.load(value);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  if (!tauri.isTauriLauncherAvailable || !isDesktopAssetPath(value)) {
    return null;
  }
  final asset = await tauri.readDesktopAsset(path: value);
  if (asset.dataBase64.isEmpty) {
    return null;
  }
  return Uint8List.fromList(base64Decode(asset.dataBase64));
}
