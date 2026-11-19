part of 'merry_go_round_carousel.dart';

/// Builds the item at [index].
///
/// [depth] goes from `0.0` (at the very back of the wheel) to `1.0`
/// (at the very front), so you can highlight the item that faces the viewer.
typedef MerryGoRoundItemBuilder = Widget Function(
  BuildContext context,
  int index,
  double depth,
);

/// Builds the text a screen reader reads for the carousel's position, for
/// example "3 of 8". [index] is zero-based.
typedef MerryGoRoundSemanticValueBuilder = String Function(
  int index,
  int count,
);

/// Which mouse-wheel and trackpad scrolls rotate a [MerryGoRoundCarousel].
///
/// A scroll the carousel doesn't handle is left for an enclosing scroll view.
enum MerryGoRoundScrollBehavior {
  /// Any scroll over the carousel rotates it, vertical or horizontal.
  always,

  /// Only horizontal scrolls rotate it: sideways trackpad swipes, a
  /// horizontal mouse wheel, or Shift + wheel. Vertical scrolls go to the
  /// page, so this is the best choice inside a vertically scrolling page.
  horizontalOnly,

  /// Any scroll rotates it, but only while the carousel has keyboard focus
  /// (after it has been clicked, tapped or tabbed to). The carousel can
  /// only take focus when `enableKeyboard` is true.
  whenFocused,

  /// Scrolling never rotates the carousel.
  never,
}

String _defaultSemanticValue(int index, int count) => '${index + 1} of $count';

/// One full turn of the ring, in radians.
const double _twoPi = 2 * math.pi;
