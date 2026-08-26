import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miriago/desktop/desktop_input.dart';
import 'package:miriago/desktop/responsive_layout.dart';
import 'package:miriago/main.dart';
import 'package:miriago/data/sample_pilgrimage_repository.dart';

void main() {
  testWidgets('content breakpoints remain usable at 360, 600, 960, 1440', (
    tester,
  ) async {
    final widths = [360.0, 600.0, 960.0, 1440.0];
    for (final width in widths) {
      await tester.binding.setSurfaceSize(Size(width, 720));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(size: Size(width, 720)),
              child: LayoutScope(
                builder: (_, tier) => Text(
                  '${tier.name}:${tier.columns}',
                  key: const ValueKey('layout-result'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final expected = width < 600
          ? 'narrow:1'
          : width < 960
          ? 'medium:2'
          : 'wide:3';
      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  test('desktop actions cover the non-text navigation keys', () {
    expect(
      desktopActionForKey(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      ),
      DesktopAction.moveDown,
    );
    expect(
      desktopActionForKey(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        ),
      ),
      DesktopAction.dismiss,
    );
    expect(
      desktopActionForKey(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
        isTyping: true,
      ),
      isNull,
    );
  });

  testWidgets('shortcut host handles Ctrl+S and ignores focused text input', (
    tester,
  ) async {
    final actions = <DesktopAction>[];
    final target = ShortcutTarget()
      ..onAction = (action) {
        actions.add(action);
        return true;
      };
    final textController = TextEditingController();
    addTearDown(textController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShortcutHost(
          targets: [target],
          selectedIndex: 0,
          onGlobalAction: (action) => actions.add(action),
          child: Scaffold(
            body: Column(
              children: [
                TextField(controller: textController),
                const Text('shortcut surface'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(actions, contains(DesktopAction.save));

    actions.clear();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(actions, contains(DesktopAction.openSettings));

    actions.clear();
    await tester.tap(find.byType(TextField));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    expect(actions, isEmpty);
  });

  testWidgets('unhandled Esc bubbles instead of being consumed', (
    tester,
  ) async {
    final bubbled = <LogicalKeyboardKey>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent) bubbled.add(event.logicalKey);
            return KeyEventResult.handled;
          },
          child: AppShortcutHost(
            targets: [ShortcutTarget()],
            selectedIndex: 0,
            onGlobalAction: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    expect(bubbled, contains(LogicalKeyboardKey.escape));
  });

  testWidgets('AppShell stays within bounds at desktop and mobile widths', (
    tester,
  ) async {
    final widths = [360.0, 600.0, 960.0, 1440.0];
    final originalDevicePixelRatio = tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.devicePixelRatio = originalDevicePixelRatio);
    for (final width in widths) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        MiriaGoApp(repository: SamplePilgrimageRepository()),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'width=$width');
      if (width >= 600) {
        await tester.tap(find.text('记录').last);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('records-inline-detail')),
          findsOneWidget,
        );
        await tester.tap(find.text('设置').last);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('settings-category-navigation')),
          findsOneWidget,
        );
      }
      if (width >= 1440) {
        await tester.tap(find.text('地图').last);
        await tester.pump();
        expect(find.byKey(const ValueKey('map-point-sidebar')), findsOneWidget);
      }
      await tester.tap(find.text('计划').last);
      await tester.pump();
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
