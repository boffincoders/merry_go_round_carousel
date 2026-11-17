import 'package:flutter/widgets.dart';

/// Card size for the current screen width: phone, tablet or desktop.
Size carouselItemSizeFor(double width) {
  if (width >= 1024) return const Size(180, 230);
  if (width >= 600) return const Size(150, 190);
  return const Size(110, 140);
}
