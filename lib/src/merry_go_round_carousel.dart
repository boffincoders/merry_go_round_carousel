import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show GestureBinding, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart';

/// Builds the item at [index].
///
/// [depth] goes from `0.0` (at the very back of the wheel) to `1.0`
/// (at the very front), so you can highlight the item that faces the viewer.
typedef MerryGoRoundItemBuilder = Widget Function(
  BuildContext context,
  int index,
  double depth,
);

/// Controls a [MerryGoRoundCarousel] from outside the widget.
///
/// Listen to it to be told when the front item changes.
class MerryGoRoundController extends ChangeNotifier {
  MerryGoRoundController({this.initialIndex = 0});

  /// The item placed at the front when the wheel is first built.
  final int initialIndex;

  _MerryGoRoundCarouselState? _state;

  /// Whether the controller is attached to a wheel.
  bool get hasClients => _state != null;

  /// Index of the item currently closest to the front.
  int get currentIndex => _state?._frontIndex ?? initialIndex;

  /// The current rotation of the wheel, in radians.
  double get angle => _state?._angle ?? 0.0;

  /// Rotates the wheel (the short way round) until [index] is at the front.
  Future<void> animateToIndex(
    int index, {
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeOutCubic,
  }) {
    final state = _state;
    if (state == null) return Future<void>.value();
    return state._animateToIndex(index, duration, curve);
  }

  /// Brings the next item (to the right of the front one) to the front.
  Future<void> next({
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOutCubic,
  }) {
    final state = _state;
    if (state == null) return Future<void>.value();
    return state._animateTo(state._stepBase() - state._step, duration, curve);
  }

  /// Brings the previous item (to the left of the front one) to the front.
  Future<void> previous({
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOutCubic,
  }) {
    final state = _state;
    if (state == null) return Future<void>.value();
    return state._animateTo(state._stepBase() + state._step, duration, curve);
  }

  /// Puts [index] at the front immediately, without animating.
  void jumpToIndex(int index) => _state?._jumpToIndex(index);

  /// Pauses automatic rotation (if `autoRotate` is on) until [resumeAutoRotate].
  void pauseAutoRotate() => _state?._setUserPaused(true);

  /// Resumes automatic rotation after [pauseAutoRotate].
  void resumeAutoRotate() => _state?._setUserPaused(false);

  void _attach(_MerryGoRoundCarouselState state) => _state = state;

  void _detach(_MerryGoRoundCarouselState state) {
    if (_state == state) _state = null;
  }

  void _notify() => notifyListeners();
}

/// A rotating "merry-go-round" carousel: items sit on a 3D ring that the user
/// can spin with a swipe, and that can also turn by itself.
class MerryGoRoundCarousel extends StatefulWidget {
  /// Creates a wheel from a fixed list of [children].
  MerryGoRoundCarousel({
    super.key,
    required List<Widget> children,
    this.controller,
    this.initialIndex = 0,
    this.radius,
    this.itemSpacing = 1.6,
    this.itemSize = const Size(110, 150),
    this.tilt = 0.25,
    this.backScale = 0.55,
    this.backOpacity = 0.55,
    this.faceOutward = true,
    this.perspective = 0.0015,
    this.autoRotate = false,
    this.autoRotateSpeed = 0.35,
    this.autoRotateResumeDelay = const Duration(seconds: 2),
    this.enableDrag = true,
    this.dragSensitivity = 1.0,
    this.enableScrollWheel = true,
    this.enableKeyboard = true,
    this.snapToItem = true,
    this.friction = 0.08,
    this.rotateOnTap = true,
    this.tapAnimationDuration = const Duration(milliseconds: 500),
    this.onIndexChanged,
    this.onItemTap,
    this.center,
  })  : itemCount = children.length,
        itemBuilder =
            ((BuildContext _, int index, double __) => children[index]);

  /// Creates a wheel whose items are built on demand.
  const MerryGoRoundCarousel.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.initialIndex = 0,
    this.radius,
    this.itemSpacing = 1.6,
    this.itemSize = const Size(110, 150),
    this.tilt = 0.25,
    this.backScale = 0.55,
    this.backOpacity = 0.55,
    this.faceOutward = true,
    this.perspective = 0.0015,
    this.autoRotate = false,
    this.autoRotateSpeed = 0.35,
    this.autoRotateResumeDelay = const Duration(seconds: 2),
    this.enableDrag = true,
    this.dragSensitivity = 1.0,
    this.enableScrollWheel = true,
    this.enableKeyboard = true,
    this.snapToItem = true,
    this.friction = 0.08,
    this.rotateOnTap = true,
    this.tapAnimationDuration = const Duration(milliseconds: 500),
    this.onIndexChanged,
    this.onItemTap,
    this.center,
  })  : assert(itemCount >= 0),
        assert(itemSpacing > 0),
        assert(tilt >= 0),
        assert(backScale > 0 && backScale <= 1),
        assert(backOpacity >= 0 && backOpacity <= 1),
        assert(friction > 0 && friction < 1);

  /// Number of items on the wheel.
  final int itemCount;

  /// Builds each item. See [MerryGoRoundItemBuilder].
  final MerryGoRoundItemBuilder itemBuilder;

  /// Optional controller for programmatic rotation.
  final MerryGoRoundController? controller;

  /// Item at the front on first build (ignored when [controller] is given;
  /// use [MerryGoRoundController.initialIndex] instead).
  final int initialIndex;

  /// Radius of the ring in logical pixels.
  ///
  /// When null, the radius is worked out from [itemCount], [itemSize] and
  /// [itemSpacing], and shrunk if needed so the ring fits the available
  /// width. This keeps the ring a sensible size on tablets and desktop
  /// browsers instead of stretching across the whole screen.
  final double? radius;

  /// Space reserved for each item around the ring, as a multiple of
  /// `itemSize.width`. Only used when [radius] is null. Larger values spread
  /// the items out (a bigger ring); smaller values pack them together.
  final double itemSpacing;

  /// Size of each item before depth scaling.
  final Size itemSize;

  /// How much the ring is viewed from above. `0` is a flat side view; larger
  /// values push front items down and back items up.
  final double tilt;

  /// Scale of the item at the very back (the front item is always `1.0`).
  final double backScale;

  /// Opacity of the item at the very back (the front item is always `1.0`).
  final double backOpacity;

  /// Whether items turn in 3D to follow the curve of the ring.
  final bool faceOutward;

  /// Strength of the 3D perspective used when [faceOutward] is true.
  final double perspective;

  /// Whether the wheel keeps turning on its own.
  final bool autoRotate;

  /// Speed of automatic rotation, in radians per second. Negative values
  /// turn the other way.
  final double autoRotateSpeed;

  /// How long automatic rotation waits after the user lets go.
  final Duration autoRotateResumeDelay;

  /// Whether the user can spin the wheel with a horizontal swipe.
  final bool enableDrag;

  /// Multiplier applied to drag distance, fling speed and scroll-wheel
  /// distance.
  final double dragSensitivity;

  /// Whether a mouse wheel or trackpad scroll over the carousel rotates it
  /// (useful on web and desktop). The carousel snaps once scrolling stops.
  final bool enableScrollWheel;

  /// Whether the left and right arrow keys rotate the carousel once it has
  /// focus. The carousel takes focus when it is clicked or tapped.
  final bool enableKeyboard;

  /// Whether the wheel settles with an item exactly at the front.
  final bool snapToItem;

  /// Fraction of fling speed kept after one second (smaller stops sooner).
  final double friction;

  /// Whether tapping an item rotates it to the front.
  final bool rotateOnTap;

  /// Duration of the tap-to-front rotation.
  final Duration tapAnimationDuration;

  /// Called whenever a different item becomes the front item.
  final ValueChanged<int>? onIndexChanged;

  /// Called when an item is tapped.
  final ValueChanged<int>? onItemTap;

  /// Optional widget drawn in the middle of the ring (the "pole"), between
  /// the back half and the front half of the items.
  final Widget? center;

  @override
  State<MerryGoRoundCarousel> createState() => _MerryGoRoundCarouselState();
}

class _MerryGoRoundCarouselState extends State<MerryGoRoundCarousel>
    with TickerProviderStateMixin {
  static const double _twoPi = 2 * math.pi;

  late final AnimationController _anim;
  Ticker? _autoTicker;
  Duration? _lastElapsed;
  Timer? _resumeTimer;
  bool _dragging = false;
  bool _interactionPause = false;
  bool _userPaused = false;
  int _lastIndex = 0;
  double _effectiveRadius = 150;
  double? _pendingTarget;
  Timer? _scrollEndTimer;
  final FocusNode _focusNode = FocusNode(debugLabel: 'MerryGoRoundCarousel');

  double get _step =>
      widget.itemCount == 0 ? _twoPi : _twoPi / widget.itemCount;
  double get _angle => _anim.value;

  int get _frontIndex {
    final n = widget.itemCount;
    if (n == 0) return 0;
    return (-_angle / _step).round() % n;
  }

  double _snapped(double angle) => (angle / _step).round() * _step;

  /// Where next/previous count from: the running animation's destination if
  /// there is one, so quick repeated taps each move one more item.
  double _stepBase() => _anim.isAnimating && _pendingTarget != null
      ? _pendingTarget!
      : _snapped(_angle);

  /// Angle that puts [index] at the front, reached the short way round.
  double _targetForIndex(int index) {
    var delta = (-index * _step - _angle) % _twoPi;
    if (delta > math.pi) delta -= _twoPi;
    return _angle + delta;
  }

  @override
  void initState() {
    super.initState();
    final start = widget.controller?.initialIndex ?? widget.initialIndex;
    _anim = AnimationController.unbounded(vsync: this, value: -start * _step)
      ..addListener(_onAngleChanged);
    widget.controller?._attach(this);
    _lastIndex = _frontIndex;
    _syncAutoRotate();
  }

  @override
  void didUpdateWidget(MerryGoRoundCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (oldWidget.itemCount != widget.itemCount) {
      final n = widget.itemCount;
      final keep = n == 0 ? 0 : _lastIndex.clamp(0, n - 1);
      _anim
        ..stop()
        ..removeListener(_onAngleChanged)
        ..value = -keep * _step
        ..addListener(_onAngleChanged);
      _lastIndex = keep;
    }
    _syncAutoRotate();
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _scrollEndTimer?.cancel();
    _focusNode.dispose();
    _autoTicker?.dispose();
    widget.controller?._detach(this);
    _anim.dispose();
    super.dispose();
  }

  void _onAngleChanged() {
    setState(() {});
    final index = _frontIndex;
    if (index != _lastIndex) {
      _lastIndex = index;
      widget.onIndexChanged?.call(index);
      widget.controller?._notify();
    }
  }

  // ---- automatic rotation -------------------------------------------------

  void _syncAutoRotate() {
    final shouldRun = widget.autoRotate && !_userPaused && widget.itemCount > 0;
    if (shouldRun && _autoTicker == null) {
      _lastElapsed = null;
      _autoTicker = createTicker(_onAutoTick)..start();
    } else if (!shouldRun && _autoTicker != null) {
      _autoTicker!.dispose();
      _autoTicker = null;
    }
  }

  void _onAutoTick(Duration elapsed) {
    final last = _lastElapsed;
    _lastElapsed = elapsed;
    if (last == null) return;
    if (_dragging || _interactionPause || _anim.isAnimating) return;
    final dt = (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    _anim.value += widget.autoRotateSpeed * dt;
  }

  void _setUserPaused(bool paused) {
    _userPaused = paused;
    _syncAutoRotate();
  }

  void _pauseForInteraction() {
    _resumeTimer?.cancel();
    _interactionPause = true;
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.autoRotateResumeDelay, () {
      _interactionPause = false;
    });
  }

  // ---- programmatic rotation ----------------------------------------------

  Future<void> _animateTo(double target, Duration duration, Curve curve) {
    if (duration == Duration.zero) {
      _anim.value = target;
      return Future<void>.value();
    }
    _pauseForInteraction();
    _pendingTarget = target;
    final future = _anim.animateTo(target, duration: duration, curve: curve);
    future.whenCompleteOrCancel(() {
      if (_pendingTarget == target) _pendingTarget = null;
      _scheduleResume();
    });
    return future.orCancel.catchError(
      (Object _) {},
      test: (Object e) => e is TickerCanceled,
    );
  }

  Future<void> _animateToIndex(int index, Duration duration, Curve curve) {
    if (widget.itemCount == 0) return Future<void>.value();
    return _animateTo(
        _targetForIndex(index % widget.itemCount), duration, curve);
  }

  void _jumpToIndex(int index) {
    if (widget.itemCount == 0) return;
    _anim.value = -(index % widget.itemCount) * _step;
  }

  // ---- gestures -----------------------------------------------------------

  void _onDragStart(DragStartDetails details) {
    _anim.stop();
    _scrollEndTimer?.cancel();
    _pauseForInteraction();
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _anim.value += details.delta.dx / _effectiveRadius * widget.dragSensitivity;
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _dragging = false);
    final velocity = details.velocity.pixelsPerSecond.dx /
        _effectiveRadius *
        widget.dragSensitivity;

    if (!widget.snapToItem) {
      _anim
          .animateWith(FrictionSimulation(widget.friction, _angle, velocity))
          .whenCompleteOrCancel(_scheduleResume);
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
    setState(() => _dragging = false);
    if (widget.snapToItem) {
      _animateTo(
          _snapped(_angle), const Duration(milliseconds: 300), Curves.easeOut);
    } else {
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
      _anim.stop();
      _pendingTarget = null;
      _pauseForInteraction();
      _anim.value -= d / _effectiveRadius * widget.dragSensitivity;
      _scrollEndTimer?.cancel();
      _scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (widget.snapToItem) {
          _animateTo(_snapped(_angle), const Duration(milliseconds: 250),
              Curves.easeOut);
        } else {
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
      _animateTo(_stepBase() - _step, duration, Curves.easeOutCubic);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _animateTo(_stepBase() + _step, duration, Curves.easeOutCubic);
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

  // ---- layout -------------------------------------------------------------

  /// Radius used when `radius` is null: big enough to space the items
  /// `itemSpacing` item-widths apart, but no wider than the available space.
  double _autoRadius(BoxConstraints constraints, Size itemSize) {
    final n = math.max(widget.itemCount, 3);
    final natural = itemSize.width * widget.itemSpacing * n / _twoPi;
    if (!constraints.hasBoundedWidth) return natural;
    final fit = math.max(0.0, (constraints.maxWidth - itemSize.width) / 2);
    return math.min(natural, fit);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemSize = widget.itemSize;
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

        return Focus(
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
      },
    );
  }
}

class _DepthEntry {
  const _DepthEntry(this.depth, this.child);
  final double depth;
  final Widget child;
}
