part of 'merry_go_round_carousel.dart';

/// Drag, scroll-wheel, keyboard and tap handling for the carousel.
extension _CarouselInput on _MerryGoRoundCarouselState {
  void _onDragStart(DragStartDetails details) {
    _stopMotion();
    _pauseForInteraction();
    _setDragging(true);
    widget.onDragStart?.call();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _anim.value += details.delta.dx / _effectiveRadius * widget.dragSensitivity;
  }

  void _onDragEnd(DragEndDetails details) {
    _setDragging(false);
    widget.onDragEnd?.call();
    final velocity = details.velocity.pixelsPerSecond.dx /
        _effectiveRadius *
        widget.dragSensitivity;

    if (!widget.snapToItem) {
      final fling = _anim
          .animateWith(FrictionSimulation(widget.friction, _angle, velocity));
      fling.then((_) => _maybeSettled());
      fling.whenCompleteOrCancel(_scheduleResume);
      return;
    }

    final projected = velocity.abs() < 0.05
        ? _angle
        : FrictionSimulation(widget.friction, _angle, velocity).finalX;
    final target = _snapped(projected);
    final distance = (target - _angle).abs();
    final millis = velocity.abs() > 0.1
        ? (2 * distance / velocity.abs() * 1000).clamp(150.0, 1400.0)
        : 300.0;
    _animateTo(
        target, Duration(milliseconds: millis.round()), Curves.decelerate);
  }

  void _onDragCancel() {
    _setDragging(false);
    widget.onDragEnd?.call();
    if (widget.snapToItem) {
      _animateTo(
          _snapped(_angle), const Duration(milliseconds: 300), Curves.easeOut);
    } else {
      _maybeSettled();
      _scheduleResume();
    }
  }

  /// The scroll behavior after applying the deprecated `enableScrollWheel`.
  MerryGoRoundScrollBehavior get _scrollBehavior =>
      // ignore: deprecated_member_use_from_same_package
      widget.enableScrollWheel
          ? widget.scrollBehavior
          : MerryGoRoundScrollBehavior.never;

  /// How far [event] should turn the wheel, in scroll pixels, or 0 if the
  /// current [MerryGoRoundCarousel.scrollBehavior] leaves it to the page.
  double _scrollDistance(PointerScrollEvent event) {
    var delta = event.scrollDelta;
    // Desktop embedders other than macOS report Shift + wheel as a vertical
    // scroll; treat it as horizontal, like Flutter's own scroll views do.
    if (event.kind == PointerDeviceKind.mouse &&
        delta.dx == 0 &&
        HardwareKeyboard.instance.isShiftPressed) {
      delta = Offset(delta.dy, 0);
    }
    final horizontal = delta.dx.abs() > delta.dy.abs();
    switch (_scrollBehavior) {
      case MerryGoRoundScrollBehavior.always:
        break;
      case MerryGoRoundScrollBehavior.horizontalOnly:
        if (!horizontal) return 0;
      case MerryGoRoundScrollBehavior.whenFocused:
        if (!_focusNode.hasFocus) return 0;
      case MerryGoRoundScrollBehavior.never:
        return 0;
    }
    return horizontal ? delta.dx : delta.dy;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (widget.itemCount == 0 || event is! PointerScrollEvent) return;
    final d = _scrollDistance(event);
    // Only claim scrolls we handle; the rest reach an enclosing scroll view.
    if (d == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!mounted) return;
      _stopMotion();
      _pauseForInteraction();
      _anim.value -= d /
          _effectiveRadius *
          (widget.scrollWheelSensitivity ?? widget.dragSensitivity);
      _scrollEndTimer?.cancel();
      _scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (widget.snapToItem) {
          _animateTo(_snapped(_angle), const Duration(milliseconds: 250),
              Curves.easeOut);
        } else {
          _maybeSettled();
          _scheduleResume();
        }
      });
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Any key press means the user is on the keyboard now: show the outline.
    if (event is KeyDownEvent) _setFocusFromPointer(false);
    if (!widget.enableKeyboard || widget.itemCount == 0) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    const duration = Duration(milliseconds: 400);
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _stepBy(1, duration, Curves.easeOutCubic);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _stepBy(-1, duration, Curves.easeOutCubic);
      return KeyEventResult.handled;
    }
    final isActivate = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.space;
    if (isActivate && widget.onItemTap != null) {
      if (event is KeyDownEvent) widget.onItemTap!(_frontIndex);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onItemTap(int index) {
    widget.onItemTap?.call(index);
    if (widget.rotateOnTap && index != _frontIndex) {
      _animateTo(_targetForIndex(index), widget.tapAnimationDuration,
          Curves.easeOutCubic);
    }
  }
}
