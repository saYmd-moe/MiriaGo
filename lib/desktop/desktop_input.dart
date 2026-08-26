import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Whether the primary keyboard focus currently belongs to a text-editing
/// field (TextField, TextFormField, SearchBar, ...). Page-level keyboard
/// shortcuts MUST NOT fire while this is true, so that normal text editing
/// (typing a comma, 'o', arrow movement inside the field, ...) is never
/// hijacked by a shortcut.
bool isTextInputFocused([FocusNode? node]) {
  final focusNode = node ?? FocusManager.instance.primaryFocus;
  if (focusNode == null) {
    return false;
  }
  final context = focusNode.context;
  if (context == null) {
    return false;
  }
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Recognised desktop keyboard actions. Kept provider-agnostic so both a
/// desktop (Tauri) and a web host can drive them.
enum DesktopAction {
  save,
  openImport,
  openExport,
  openSettings,
  focusSearch,
  dismiss,
  moveUp,
  moveDown,
  moveLeft,
  moveRight,
}

/// Maps a raw [KeyEvent] to a [DesktopAction], or null when it is not one of
/// the bound shortcuts. [isTyping] short-circuits to null so that no action is
/// produced while the user edits text.
DesktopAction? desktopActionForKey(KeyEvent event, {bool isTyping = false}) {
  if (isTyping) {
    return null;
  }
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return null;
  }
  final key = event.logicalKey;
  final isCtrl = HardwareKeyboard.instance.isControlPressed;
  if (isCtrl) {
    switch (key) {
      case LogicalKeyboardKey.keyS:
        return DesktopAction.save;
      case LogicalKeyboardKey.keyO:
        return DesktopAction.openImport;
      case LogicalKeyboardKey.keyE:
        return DesktopAction.openExport;
      case LogicalKeyboardKey.comma:
        return DesktopAction.openSettings;
      case LogicalKeyboardKey.keyF:
        return DesktopAction.focusSearch;
    }
    return null;
  }

  switch (key) {
    case LogicalKeyboardKey.escape:
      return DesktopAction.dismiss;
    case LogicalKeyboardKey.arrowUp:
      return DesktopAction.moveUp;
    case LogicalKeyboardKey.arrowDown:
      return DesktopAction.moveDown;
    case LogicalKeyboardKey.arrowLeft:
      return DesktopAction.moveLeft;
    case LogicalKeyboardKey.arrowRight:
      return DesktopAction.moveRight;
  }
  return null;
}

/// A slot that a single page fills (at build/init time) with its own shortcut
/// handler. The app-level host dispatches key events to the target of the
/// currently-selected tab, which keeps per-page shortcut state (selected point,
/// list index, open dialogs) inside the page while all raw key handling stays
/// at a single focused host. This avoids the IndexedStack focus pitfalls where
/// offstage pages never reliably receive key events.
class ShortcutTarget {
  /// Called with a resolved action and returns whether the page handled it.
  bool Function(DesktopAction action)? onAction;
}

/// App-level keyboard host. Installs one focused `Focus` (autofocused by
/// default) that translates raw keys into [DesktopAction]s and routes them:
///
/// * global navigation actions ([DesktopAction.openSettings],
///   [DesktopAction.openImport], [DesktopAction.openExport]) go to
///   [onGlobalAction];
/// * page-specific actions go to `targets[selectedIndex]`.
///
/// While a text field has focus every action is suppressed so normal text
/// editing is never hijacked by a shortcut.
class AppShortcutHost extends StatefulWidget {
  const AppShortcutHost({
    required this.targets,
    required this.selectedIndex,
    required this.onGlobalAction,
    required this.child,
    this.autofocus = true,
    super.key,
  });

  final List<ShortcutTarget?> targets;
  final int selectedIndex;
  final void Function(DesktopAction action)? onGlobalAction;
  final Widget child;
  final bool autofocus;

  @override
  State<AppShortcutHost> createState() => _AppShortcutHostState();
}

class _AppShortcutHostState extends State<AppShortcutHost> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'desktop-shortcut-host');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final action = desktopActionForKey(event, isTyping: isTextInputFocused());
    if (action == null) {
      return KeyEventResult.ignored;
    }
    if (widget.onGlobalAction != null && _isGlobal(action)) {
      widget.onGlobalAction!(action);
      return KeyEventResult.handled;
    }
    final target =
        (widget.selectedIndex >= 0 &&
            widget.selectedIndex < widget.targets.length)
        ? widget.targets[widget.selectedIndex]
        : null;
    final handled = target?.onAction?.call(action) ?? false;
    return handled ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  bool _isGlobal(DesktopAction action) {
    return switch (action) {
      DesktopAction.openSettings ||
      DesktopAction.openImport ||
      DesktopAction.openExport => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}

/// Handles desktop keyboard shortcuts for a single standalone page (not inside
/// the app's IndexedStack). Useful for pushed screens such as import/export or
/// plan management that own their own Scaffold and focus.
class DesktopShortcutHandler extends StatefulWidget {
  const DesktopShortcutHandler({
    required this.child,
    this.actions,
    this.autofocus = true,
    super.key,
  });

  final Widget child;
  final void Function(DesktopAction action)? actions;
  final bool autofocus;

  @override
  State<DesktopShortcutHandler> createState() => _DesktopShortcutHandlerState();
}

class _DesktopShortcutHandlerState extends State<DesktopShortcutHandler> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'desktop-page-shortcuts');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final typing = isTextInputFocused(node) || isTextInputFocused();
    final action = desktopActionForKey(event, isTyping: typing);
    if (action == null) {
      return KeyEventResult.ignored;
    }
    widget.actions?.call(action);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
