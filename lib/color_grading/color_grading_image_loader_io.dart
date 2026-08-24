import 'dart:io';

import 'package:flutter/services.dart';

import '../data/app_managed_file_paths_io.dart';

Future<Uint8List?> loadColorGradingImageBytes(String path) async {
  final value = path.trim();
  if (value.isEmpty) {
    return null;
  }

  if (value.startsWith('docs/sample_images/')) {
    final data = await rootBundle.load(value);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  final resolvedPath = resolveExistingAppManagedFilePathSync(value) ?? value;
  final file = File(resolvedPath);
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}
