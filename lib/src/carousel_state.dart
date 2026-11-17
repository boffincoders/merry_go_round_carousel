part of 'merry_go_round_carousel.dart';

/// Lifecycle, animation and auto-rotation for [MerryGoRoundCarousel].
///
/// Input handling lives in `carousel_input.dart` and drawing in
/// `carousel_layout.dart`, as private extensions on this class.
class _MerryGoRoundCarouselState extends State<MerryGoRoundCarousel>
    with TickerProviderStateMixin {
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

  /// Front item the last time the wheel was at rest.
  int _settledIndex = 0;

  /// The platform asked for reduced motion (MediaQuery.disableAnimations).
  bool _reduceMotion = false;

  /// A screen reader or similar service is in use.
  bool _accessibleNavigation = false;

  double get _step =>
      widget.itemCount == 0 ? _twoPi : _twoPi / widget.itemCount;
  double get _angle => _anim.value;

  int get _frontIndex {
    final n = widget.itemCount;
    if (n == 0) return 0;
    return (-_angle / _step).round() % n;
  }

  double _snapped(double angle) => (angle / _step).round() * _step;

  bool get _isAutoRotating =>
      _autoTicker != null && !_interactionPause && !_dragging;

  bool get _isMoving => _dragging || _anim.isAnimating || _isAutoRotating;

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
    _settledIndex = _lastIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _accessibleNavigation =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
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
      final previous = _lastIndex;
      final keep = n == 0 ? 0 : previous.clamp(0, n - 1);
      _stopMotion();
      _anim
        ..removeListener(_onAngleChanged)
        ..value = -keep * _step
        ..addListener(_onAngleChanged);
      _lastIndex = keep;
      if (keep != previous) {
        // The list shrank past the front item, so a different item is now
        // at the front. Report it after this frame, because the callbacks
        // may call setState on an ancestor that is still building.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _lastIndex != keep) return;
          widget.onIndexChanged?.call(keep);
          widget.controller?._notify();
          _maybeSettled();
        });
      }
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
    final shouldRun = widget.autoRotate &&
        !_userPaused &&
        !_reduceMotion &&
        !_accessibleNavigation &&
        widget.itemCount > 0;
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
    // Not after dispose (an animation cancelled by dispose still runs its
    // callbacks), not mid-drag, and not while a newer animation is running:
    // that one schedules the resume when it finishes.
    if (!mounted || _dragging || _anim.isAnimating) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.autoRotateResumeDelay, () {
      _interactionPause = false;
    });
  }

  // ---- motion bookkeeping -------------------------------------------------

  /// Stops whatever is moving the wheel and forgets queued navigation.
  ///
  /// Policy: a drag, a scroll-wheel turn, a jump or a change in item count
  /// cancels any running animation and pending next/previous steps. A new
  /// next/previous while one is running is queued on top of it instead (see
  /// [_stepBase]).
  void _stopMotion() {
    _anim.stop();
    _pendingTarget = null;
    _scrollEndTimer?.cancel();
  }

  /// Reports [MerryGoRoundCarousel.onSelectedItemChanged] if the wheel is at
  /// rest with a different item at the front than last time.
  void _maybeSettled() {
    if (!mounted || widget.itemCount == 0 || _isMoving) return;
    if (_scrollEndTimer?.isActive ?? false) return;
    final index = _frontIndex;
    if (index == _settledIndex) return;
    _settledIndex = index;
    widget.onSelectedItemChanged?.call(index);
  }

  // ---- programmatic rotation ----------------------------------------------

  Future<void> _animateTo(double target, Duration duration, Curve curve) {
    // The user's finger wins over programmatic rotation.
    if (_dragging) return Future<void>.value();
    if (duration == Duration.zero || _reduceMotion) {
      _stopMotion();
      _anim.value = target;
      _maybeSettled();
      return Future<void>.value();
    }
    _pauseForInteraction();
    _pendingTarget = target;
    final future = _anim.animateTo(target, duration: duration, curve: curve);
    future.then((_) => _maybeSettled());
    future.whenCompleteOrCancel(() {
      if (_pendingTarget == target) _pendingTarget = null;
      _scheduleResume();
    });
    return future.orCancel.catchError(
      (Object _) {},
      test: (Object e) => e is TickerCanceled,
    );
  }

  /// Moves [direction] items forward (1) or back (-1). Steps requested while
  /// one is still running are added on top of it.
  Future<void> _stepBy(int direction, Duration duration, Curve curve) {
    // With fewer than two items there is nowhere to go; don't spin a full
    // circle back to the same item.
    if (widget.itemCount < 2) return Future<void>.value();
    return _animateTo(_stepBase() - direction * _step, duration, curve);
  }

  Future<void> _animateToIndex(int index, Duration duration, Curve curve) {
    if (widget.itemCount == 0) return Future<void>.value();
    return _animateTo(
        _targetForIndex(index % widget.itemCount), duration, curve);
  }

  void _jumpToIndex(int index) {
    if (widget.itemCount == 0) return;
    _stopMotion();
    _anim.value = -(index % widget.itemCount) * _step;
    _maybeSettled();
  }

  /// Updates [_dragging] and rebuilds (for the grab / grabbing cursor).
  void _setDragging(bool dragging) {
    if (_dragging == dragging) return;
    setState(() => _dragging = dragging);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildRing);
  }
}
