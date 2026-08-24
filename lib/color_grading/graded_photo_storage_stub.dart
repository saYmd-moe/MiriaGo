import 'dart:convert';
import 'dart:typed_data';

import '../desktop/tauri_bridge.dart' as tauri;

Future<String?> saveGradedPhoto({
  required Uint8List bytes,
  required String recordId,
}) async {
  if (!tauri.isTauriLauncherAvailable || bytes.isEmpty) {
    return null;
  }

  final safeRecordId = recordId.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path = 'assets/graded_photos/graded_${safeRecordId}_$timestamp.jpg';
  try {
    await tauri.writeDesktopAsset(path: path, dataBase64: base64Encode(bytes));
    return path;
  } on Object {
    return null;
  }
}
