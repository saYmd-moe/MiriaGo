import 'package:flutter/material.dart';

/// Content-driven responsive layout breakpoints.
///
/// Breakpoints are chosen from the minimum usable content widths of the app's
/// high-frequency pages rather than from device classes, so a resizeable
/// desktop window and a phone report consistently by their real available
/// width.
class AppLayout {
  const AppLayout._();

  /// Below this width a single-column layout is used (current mobile flow).
  static const double mediumMin = 600;

  /// At/above this width a three-column / map+list+detail layout is preferred.
  static const double wideMin = 960;

  /// One of the coarse layout tiers used by pages to pick a column plan.
  static LayoutTier tierFor(double width) {
    if (width >= wideMin) {
      return LayoutTier.wide;
    }
    if (width >= mediumMin) {
      return LayoutTier.medium;
    }
    return LayoutTier.narrow;
  }
}

enum LayoutTier { narrow, medium, wide }

extension LayoutTierCustom on LayoutTier {
  bool get isNarrow => this == LayoutTier.narrow;
  bool get isMedium => this == LayoutTier.medium;
  bool get isWide => this == LayoutTier.wide;

  /// Number of parallel content columns the page should show.
  int get columns => switch (this) {
    LayoutTier.narrow => 1,
    LayoutTier.medium => 2,
    LayoutTier.wide => 3,
  };
}

/// A convenience wrapper exposing the current [LayoutTier] to descendants,
/// letting pages branch on content width without recomputing it.
class LayoutScope extends StatelessWidget {
  const LayoutScope({required this.builder, super.key});

  final Widget Function(BuildContext context, LayoutTier tier) builder;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return builder(context, AppLayout.tierFor(width));
  }
}

/// Left sidebar + main content two-column split for medium/wide layouts.
///
/// The [sidebar] is a fixed-width column on the left while [content] fills the
/// remaining space. On narrow tiers the split renders as a plain vertical
/// column (sidebar above content) unless [forceColumns] is set.
class SplitPane extends StatelessWidget {
  const SplitPane({
    required this.tier,
    required this.sidebar,
    required this.content,
    this.sidebarWidth = 320,
    this.sidebarFlex,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final LayoutTier tier;
  final Widget sidebar;
  final Widget content;
  final double sidebarWidth;
  final int? sidebarFlex;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (tier.isNarrow) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [sidebar, content],
        ),
      );
    }
    final sidebarWidget = SizedBox(width: sidebarWidth, child: sidebar);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sidebarWidget,
          const SizedBox(width: 12),
          Expanded(child: content),
        ],
      ),
    );
  }
}
