## 0.2.0

**New**
- `onSelectedItemChanged`: called when the wheel comes to rest on a different item. Unlike `onIndexChanged`, it doesn't fire for items that only pass the front during a spin.
- `onDragStart` / `onDragEnd` callbacks.
- `MerryGoRoundController.isMoving` and `isAutoRotating`.
- Accessibility: the carousel is an adjustable control for screen readers (`semanticLabel`, `semanticValueBuilder`, swipe up/down to rotate). Items are read in list order with the front item marked selected. Enter/Space activates the front item.
- Respects reduced motion (`MediaQuery.disableAnimations`): no auto-rotation, and steps move instantly.
- `addRepaintBoundaries` (default `true`) wraps each item in a `RepaintBoundary`.

**Fixes**
- Disposing the carousel during an animation no longer leaves a pending timer behind.
- A drag, scroll-wheel turn, jump or item-count change now always cancels the running animation and any queued next/previous steps.
- After an animation was replaced by another, auto-rotation could resume immediately instead of after `autoRotateResumeDelay`.
- When the list shrinks past the front item, `onIndexChanged` and controller listeners are now told about the new front item.
- `next()` / `previous()` with fewer than two items no longer spin a full circle.
- Programmatic rotation is ignored while the user is dragging.
- Auto-rotation is paused while a screen reader is running.

**Other**
- Both constructors now validate their arguments the same way (radius, spacing, sensitivity, perspective, friction, initial index; item size is checked at build time).
- Many new tests covering lifecycle and interaction edge cases.
- Source split into smaller files (widget, state, input, layout, controller, types). No API change.

## 0.1.0

- First release: `MerryGoRoundCarousel`, `MerryGoRoundCarousel.builder` and `MerryGoRoundController`.
- Ring sizes itself from the item count (`itemSpacing`) instead of filling the full width, so it looks right on tablets and web.
- Mouse wheel / trackpad scrolling, arrow-key navigation and mouse cursors for web and desktop.
