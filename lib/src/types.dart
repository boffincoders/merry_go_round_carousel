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

String _defaultSemanticValue(int index, int count) => '${index + 1} of $count';

/// One full turn of the ring, in radians.
const double _twoPi = 2 * math.pi;
