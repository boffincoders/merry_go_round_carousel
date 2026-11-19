## 0.3.0

**New**
- `scrollBehavior` (`MerryGoRoundScrollBehavior`): choose which mouse-wheel and trackpad scrolls turn the carousel: `always` (default, as before), `horizontalOnly`, `whenFocused` or `never`. Scrolls the carousel doesn't handle now reach an enclosing scroll view, so with `horizontalOnly` a page with a carousel on it scrolls normally under the mouse wheel. Shift + wheel counts as horizontal on every desktop platform.
- `scrollWheelSensitivity`: tune scroll-wheel speed separately from `dragSensitivity` (which it falls back to).
- Keyboard focus outline: while the carousel has keyboard focus, the front item is outlined, so keyboard users can see where focus is and which item Enter/Space activates. It is only drawn for keyboard navigation, not after a click or tap. Customise it with `focusDecoration`, or turn it off with `showFocusHighlight: false`.

**Deprecated**
- `enableScrollWheel`. Use `scrollBehavior: MerryGoRoundScrollBehavior.never` instead of `enableScrollWheel: false`. It still works in 0.3.0 and will be removed in a later release. Setting both is an error.

**Example**
- The "From server" page uses `horizontalOnly`, so the mouse wheel scrolls its details section.
- The "From server" page can now be opened from the app bar (it wasn't reachable before).
- Frame-timing benchmarks: `integration_test/carousel_perf_test.dart` and `test_driver/perf_driver.dart`. See the example's README.

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
