part of 'merry_go_round_carousel.dart';

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
    this.onSelectedItemChanged,
    this.onItemTap,
    this.onDragStart,
    this.onDragEnd,
    this.center,
    this.addRepaintBoundaries = true,
    this.semanticLabel,
    this.semanticValueBuilder = _defaultSemanticValue,
  })  : itemCount = children.length,
        itemBuilder =
            ((BuildContext _, int index, double __) => children[index]),
        assert(initialIndex >= 0),
        assert((radius ?? 1) > 0 && (radius ?? 1) < double.infinity),
        assert(itemSpacing > 0 && itemSpacing < double.infinity),
        assert(tilt >= 0 && tilt < double.infinity),
        assert(backScale > 0 && backScale <= 1),
        assert(backOpacity >= 0 && backOpacity <= 1),
        assert(perspective >= 0 && perspective < double.infinity),
        assert(autoRotateSpeed > -double.infinity &&
            autoRotateSpeed < double.infinity),
        assert(dragSensitivity > 0 && dragSensitivity < double.infinity),
        assert(friction > 0 && friction < 1);

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
    this.onSelectedItemChanged,
    this.onItemTap,
    this.onDragStart,
    this.onDragEnd,
    this.center,
    this.addRepaintBoundaries = true,
    this.semanticLabel,
    this.semanticValueBuilder = _defaultSemanticValue,
  })  : assert(itemCount >= 0),
        assert(initialIndex >= 0),
        assert((radius ?? 1) > 0 && (radius ?? 1) < double.infinity),
        assert(itemSpacing > 0 && itemSpacing < double.infinity),
        assert(tilt >= 0 && tilt < double.infinity),
        assert(backScale > 0 && backScale <= 1),
        assert(backOpacity >= 0 && backOpacity <= 1),
        assert(perspective >= 0 && perspective < double.infinity),
        assert(autoRotateSpeed > -double.infinity &&
            autoRotateSpeed < double.infinity),
        assert(dragSensitivity > 0 && dragSensitivity < double.infinity),
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

  /// Called whenever a different item becomes the front item, including
  /// items that only pass the front while the wheel is spinning.
  ///
  /// For work that should only happen once the user has made a choice (such
  /// as loading details for the selected item), use [onSelectedItemChanged].
  final ValueChanged<int>? onIndexChanged;

  /// Called when the wheel comes to rest with a different item at the front
  /// than the last time it was at rest.
  ///
  /// Unlike [onIndexChanged], this is not called for items that only pass the
  /// front during a spin. While the wheel is turning on its own
  /// ([autoRotate]) it is never at rest, so this is not called until
  /// automatic rotation pauses.
  final ValueChanged<int>? onSelectedItemChanged;

  /// Called when an item is tapped, and when Enter or Space is pressed while
  /// the carousel has focus (with the front item's index).
  final ValueChanged<int>? onItemTap;

  /// Called when the user starts dragging the wheel.
  final VoidCallback? onDragStart;

  /// Called when the user lets go of the wheel (or the drag is cancelled).
  final VoidCallback? onDragEnd;

  /// Optional widget drawn in the middle of the ring (the "pole"), between
  /// the back half and the front half of the items.
  final Widget? center;

  /// Whether to wrap each item in a [RepaintBoundary].
  ///
  /// The wheel moves every item on every animation frame, but the items'
  /// contents rarely change. A repaint boundary lets Flutter reuse each
  /// item's painting while it moves. Set to false for very simple items.
  final bool addRepaintBoundaries;

  /// Label read by screen readers for the carousel as a whole, for example
  /// "Destinations".
  final String? semanticLabel;

  /// Builds the position text read by screen readers, such as "3 of 8".
  /// Override it to translate the text.
  final MerryGoRoundSemanticValueBuilder semanticValueBuilder;

  @override
  State<MerryGoRoundCarousel> createState() => _MerryGoRoundCarouselState();
}
