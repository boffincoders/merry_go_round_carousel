part of 'merry_go_round_carousel.dart';

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

  /// Whether the wheel is moving: being dragged, animating (a snap, fling or
  /// programmatic rotation) or turning on its own.
  ///
  /// Listeners are not notified when this changes; use
  /// `MerryGoRoundCarousel.onSelectedItemChanged` to react when the wheel
  /// comes to rest.
  bool get isMoving => _state?._isMoving ?? false;

  /// Whether automatic rotation is currently turning the wheel (it is not
  /// while paused, during user interaction, or when the platform asks for
  /// reduced motion).
  bool get isAutoRotating => _state?._isAutoRotating ?? false;

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
    return state._stepBy(1, duration, curve);
  }

  /// Brings the previous item (to the left of the front one) to the front.
  Future<void> previous({
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeOutCubic,
  }) {
    final state = _state;
    if (state == null) return Future<void>.value();
    return state._stepBy(-1, duration, curve);
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
