import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/home_tone.dart';

/// Lays [child] under [header], pulled up by [overlap] so it sits on top of
/// the header's lower edge (the rounded white sheet over the violet banner).
///
/// Unlike shifting the child with a Transform, the overlapping part is
/// really placed there, so it can be tapped.
class OverlapHeader extends MultiChildRenderObjectWidget {
  OverlapHeader({
    super.key,
    required Widget header,
    required Widget child,
    required this.overlap,
  }) : super(children: [header, child]);

  final double overlap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderOverlapHeader(overlap);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderOverlapHeader renderObject,
  ) {
    renderObject.overlap = overlap;
  }
}

class _OverlapParentData extends ContainerBoxParentData<RenderBox> {}

class RenderOverlapHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OverlapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OverlapParentData> {
  RenderOverlapHeader(this._overlap);

  double _overlap;
  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OverlapParentData) {
      child.parentData = _OverlapParentData();
    }
  }

  @override
  void performLayout() {
    final header = firstChild!;
    final body = childAfter(header)!;
    final width = constraints.maxWidth;
    final inner = BoxConstraints.tightFor(width: width);
    header.layout(inner, parentUsesSize: true);
    body.layout(inner, parentUsesSize: true);
    (header.parentData! as _OverlapParentData).offset = Offset.zero;
    final top = (header.size.height - _overlap).clamp(0.0, double.infinity);
    (body.parentData! as _OverlapParentData).offset = Offset(0, top);
    size = constraints.constrain(
      Size(
        width,
        (top + body.size.height).clamp(header.size.height, double.infinity),
      ),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _height(width);

  double _height(double width) {
    final header = firstChild!;
    final body = childAfter(header)!;
    final top = (header.getMaxIntrinsicHeight(width) - _overlap).clamp(
      0.0,
      double.infinity,
    );
    return top + body.getMaxIntrinsicHeight(width);
  }

  // Header first, body on top.
  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  // The body is on top, so it gets taps first; hit testing walks the
  // children from last to first.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// A fixed [header] at the top and a scrolling [body] below it. The body
/// starts [overlap] pixels up, over the header's lower edge, inside a sheet
/// with rounded top corners, so content scrolls under the rounded edge
/// while the header stays still.
class PinnedHeader extends StatelessWidget {
  const PinnedHeader({
    super.key,
    required this.header,
    required this.body,
    this.overlap = 28,
    this.sheetColor,
    this.radius = 28,
  });

  final Widget header;

  /// Usually a ListView; it fills the space under the header.
  final Widget body;
  final double overlap;

  /// Colour of the sheet behind the scrolling content (the page's light
  /// background by default), so the rounded edge shows over the header.
  final Color? sheetColor;

  /// Corner radius of the sheet's top edge.
  final double radius;

  /// Space between the sheet's rounded edge and the first item.
  static const double topGap = 16;

  @override
  Widget build(BuildContext context) => _PinnedLayout(
    overlap: overlap,
    header: header,
    body: ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      child: ColoredBox(
        color: sheetColor ?? HomeTone.canvas,
        child: Padding(
          padding: const EdgeInsets.only(top: topGap),
          // The header already handles the status bar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: body,
          ),
        ),
      ),
    ),
  );
}

class _PinnedLayout extends MultiChildRenderObjectWidget {
  _PinnedLayout({
    required Widget header,
    required Widget body,
    required this.overlap,
  }) : super(children: [header, body]);

  final double overlap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPinnedHeader(overlap);

  @override
  void updateRenderObject(BuildContext context, RenderPinnedHeader render) {
    render.overlap = overlap;
  }
}

class RenderPinnedHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OverlapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OverlapParentData> {
  RenderPinnedHeader(this._overlap);

  double _overlap;
  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OverlapParentData) {
      child.parentData = _OverlapParentData();
    }
  }

  @override
  void performLayout() {
    final header = firstChild!;
    final body = childAfter(header)!;
    final size = constraints.biggest;
    header.layout(
      BoxConstraints.tightFor(width: size.width),
      parentUsesSize: true,
    );
    final top = (header.size.height - _overlap).clamp(0.0, size.height);
    body.layout(
      BoxConstraints.tightFor(width: size.width, height: size.height - top),
    );
    (header.parentData! as _OverlapParentData).offset = Offset.zero;
    (body.parentData! as _OverlapParentData).offset = Offset(0, top);
    this.size = size;
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  // The body is on top where they overlap, so it gets taps first.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
