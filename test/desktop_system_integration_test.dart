import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';
import 'package:miriago/desktop/tauri_bridge.dart';
import 'package:miriago/plan_transfer/plan_export_v2.dart';
import 'package:miriago/plan_transfer/plan_import_file_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('desktop fallback does not require Tauri APIs', () async {
    expect(isTauriLauncherAvailable, isFalse);
    expect(await takePendingDesktopPlanFiles(), isEmpty);
    expect(await loadDesktopDiagnostics(), isNull);
    expect(await notifyDesktopTask(title: 'ignored', body: 'ignored'), isFalse);
  });

  test('diagnostic export text does not contain a full home path', () {
    const diagnostics = RuntimeDiagnostics(
      appVersion: '1.0.0',
      tauriVersion: '2.0.0',
      webkitgtkVersion: null,
      sessionType: 'wayland',
      sessionDesktop: 'plasma',
      currentDesktop: 'KDE',
      display: null,
      waylandDisplay: 'wayland-0',
      gtkUsePortal: '1',
      portalBackend: 'kde',
      dataDir: '~/.local/share/MiriaGo',
      logsDir: '~/.local/share/MiriaGo/logs',
    );
    expect(diagnostics.text, contains('data_dir=~/.local/share/MiriaGo'));
    expect(diagnostics.text, isNot(contains('/home/example')));
    expect(diagnostics.text, isNot(contains('USERPROFILE')));
  });

  test('desktop import accepts Unicode and space paths', () async {
    final repository = SamplePilgrimageRepository();
    final plan = await repository.loadActivePlan();
    final records = await repository.loadVisitRecords(plan.id);
    final package = await buildPlanExportV2Package(
      plan: plan,
      visitRecords: records,
      options: const PlanExportV2Options(
        mode: PlanExportV2Mode.planOnly,
        includeFullReferenceCache: false,
      ),
    );
    final directory = await Directory.systemTemp.createTemp('miriago 桌面 test ');
    final path = File('${directory.path}/计划 with spaces.sjhplan');
    await path.writeAsBytes(package.bytes);

    try {
      final imported = await readPlanImportPackageFromPath(path.path);
      expect(imported.package.plan.id, plan.id);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
