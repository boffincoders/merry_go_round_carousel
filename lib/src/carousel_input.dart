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

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.enableScrollWheel || widget.itemCount == 0) return;
    if (event is! PointerScrollEvent) return;
    // Claim the event so an enclosing scroll view doesn't also scroll.
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final delta = (e as PointerScrollEvent).scrollDelta;
      final d = delta.dx.abs() > delta.dy.abs() ? delta.dx : delta.dy;
      if (d == 0) return;
      _stopMotion();
      _pauseForInteraction();
      _anim.value -= d / _effectiveRadius * widget.dragSensitivity;
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
