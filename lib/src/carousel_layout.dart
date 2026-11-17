part of 'merry_go_round_carousel.dart';

/// Positions the items on the ring and wraps them in the gesture, focus and
/// semantics widgets.
extension _CarouselLayout on _MerryGoRoundCarouselState {
  /// Radius used when `radius` is null: big enough to space the items
  /// `itemSpacing` item-widths apart, but no wider than the available space.
  double _autoRadius(BoxConstraints constraints, Size itemSize) {
    final n = math.max(widget.itemCount, 3);
    final natural = itemSize.width * widget.itemSpacing * n / _twoPi;
    if (!constraints.hasBoundedWidth) return natural;
    final fit = math.max(0.0, (constraints.maxWidth - itemSize.width) / 2);
    return math.min(natural, fit);
  }

  /// Builds the ring for the space the parent allows.
  Widget _buildRing(BuildContext context, BoxConstraints constraints) {
    final itemSize = widget.itemSize;
    assert(
      itemSize.width > 0 &&
          itemSize.height > 0 &&
          itemSize.width.isFinite &&
          itemSize.height.isFinite,
      'itemSize must be positive and finite, got $itemSize',
    );
    final front = _frontIndex;
    final radius = widget.radius ?? _autoRadius(constraints, itemSize);
    _effectiveRadius = math.max(radius, 1.0);

    final size = constraints.constrain(Size(
      radius * 2 + itemSize.width,
      itemSize.height + radius * 2 * widget.tilt,
    ));
    final cx = size.width / 2;
    final cy = size.height / 2;

    final entries = <_DepthEntry>[];
    for (var i = 0; i < widget.itemCount; i++) {
      final theta = _angle + i * _step;
      final s = math.sin(theta);
      final c = math.cos(theta);
      final depth = (c + 1) / 2; // 0 = back, 1 = front
      final scale = widget.backScale + (1 - widget.backScale) * depth;
      final opacity = widget.backOpacity + (1 - widget.backOpacity) * depth;

      Widget child = widget.itemBuilder(context, i, depth);
      if (widget.addRepaintBoundaries) {
        child = RepaintBoundary(child: child);
      }
      if (widget.faceOutward) {
        // Turn the item to follow the ring, but keep it facing the viewer
        // (no mirrored back faces).
        final faceAngle = math.atan2(s, c.abs());
        child = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, widget.perspective)
            ..rotateY(-faceAngle),
          child: child,
        );
      }
      if (opacity < 1) child = Opacity(opacity: opacity, child: child);

      entries.add(_DepthEntry(
        c,
        Positioned(
          key: ValueKey<int>(i),
          left: cx + s * radius - itemSize.width / 2,
          top: cy + c * radius * widget.tilt - itemSize.height / 2,
          width: itemSize.width,
          height: itemSize.height,
          child: Transform.scale(
            scale: scale,
            // Screen readers go through the items in list order, not in
            // the order they happen to be painted.
            child: Semantics(
              container: true,
              sortKey: OrdinalSortKey(i.toDouble()),
              selected: i == front,
              child: MouseRegion(
                cursor: widget.rotateOnTap || widget.onItemTap != null
                    ? SystemMouseCursors.click
                    : MouseCursor.defer,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onItemTap(i),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ));
    }

    if (widget.center != null) {
      entries.add(_DepthEntry(
        0,
        Positioned.fill(
          key: const ValueKey<String>('merry_go_round_center'),
          child: Center(child: widget.center),
        ),
      ));
    }

    entries.sort((a, b) => a.depth.compareTo(b.depth));

    Widget wheel = SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [for (final e in entries) e.child],
      ),
    );

    if (widget.enableDrag) {
      wheel = MouseRegion(
        cursor: _dragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          child: wheel,
        ),
      );
    }

    wheel = Focus(
      focusNode: _focusNode,
      canRequestFocus: widget.enableKeyboard,
      skipTraversal: !widget.enableKeyboard,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          if (widget.enableKeyboard) _focusNode.requestFocus();
        },
        onPointerSignal: _onPointerSignal,
        child: wheel,
      ),
    );

    // Screen readers see the carousel as one adjustable control
    // ("3 of 8"; swipe up/down to rotate) containing the items.
    final n = widget.itemCount;
    const duration = Duration(milliseconds: 400);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      value: n == 0 ? null : widget.semanticValueBuilder(front, n),
      increasedValue:
          n < 2 ? null : widget.semanticValueBuilder((front + 1) % n, n),
      decreasedValue:
          n < 2 ? null : widget.semanticValueBuilder((front + n - 1) % n, n),
      onIncrease:
          n < 2 ? null : () => _stepBy(1, duration, Curves.easeOutCubic),
      onDecrease:
          n < 2 ? null : () => _stepBy(-1, duration, Curves.easeOutCubic),
      child: wheel,
    );
  }
}

/// An item (or the center widget) with how far forward it sits, used to paint
/// back items first.
class _DepthEntry {
  const _DepthEntry(this.depth, this.child);
  final double depth;
  final Widget child;
}
