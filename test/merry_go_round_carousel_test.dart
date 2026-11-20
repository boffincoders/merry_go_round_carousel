import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merry_go_round_carousel/merry_go_round_carousel.dart';

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 400, child: child))),
    );

List<Widget> _items(int n) => [
      for (var i = 0; i < n; i++)
        Container(
            key: ValueKey('item$i'), color: Colors.blue, child: Text('$i')),
    ];

void main() {
  testWidgets('renders every item', (tester) async {
    await tester.pumpWidget(_app(MerryGoRoundCarousel(children: _items(6))));
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('item$i')), findsOneWidget);
    }
  });

  testWidgets('controller.next and previous change the front item',
      (tester) async {
    final controller = MerryGoRoundController();
    final changes = <int>[];
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      controller: controller,
      onIndexChanged: changes.add,
      children: _items(5),
    )));

    expect(controller.currentIndex, 0);
    controller.next();
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);

    controller.previous();
    controller.previous();
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 4);
    expect(changes.last, 4);
  });

  testWidgets('animateToIndex and jumpToIndex', (tester) async {
    final controller = MerryGoRoundController(initialIndex: 2);
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      controller: controller,
      children: _items(8),
    )));
    expect(controller.currentIndex, 2);

    controller.animateToIndex(6);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 6);

    controller.jumpToIndex(3);
    await tester.pump();
    expect(controller.currentIndex, 3);
  });

  testWidgets('a swipe rotates the wheel and snaps to an item', (tester) async {
    final controller = MerryGoRoundController();
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      controller: controller,
      children: _items(6),
    )));

    await tester.fling(
      find.byType(MerryGoRoundCarousel),
      const Offset(-150, 0),
      600,
    );
    await tester.pumpAndSettle();

    expect(controller.currentIndex, isNot(0));
    const step = 2 * 3.141592653589793 / 6;
    final remainder =
        (controller.angle / step) - (controller.angle / step).round();
    expect(remainder.abs(), lessThan(1e-6));
  });

  testWidgets('tapping an item brings it to the front', (tester) async {
    final controller = MerryGoRoundController();
    final taps = <int>[];
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      controller: controller,
      onItemTap: taps.add,
      children: _items(4),
    )));

    await tester.tap(find.byKey(const ValueKey('item1')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, [1]);
    expect(controller.currentIndex, 1);
  });

  testWidgets('ring does not stretch across a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: MerryGoRoundCarousel(
            itemSize: const Size(110, 150),
            children: _items(6),
          ),
        ),
      ),
    ));

    // Natural radius = 110 * 1.6 * 6 / 2pi ~= 168, so the ring is ~446 wide,
    // not the full 1600.
    final width = tester.getSize(find.byType(MerryGoRoundCarousel)).width;
    expect(
        width, closeTo(110 + 2 * 110 * 1.6 * 6 / (2 * 3.141592653589793), 1));
  });

  testWidgets('ring still shrinks to fit a narrow screen', (tester) async {
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      itemSize: const Size(110, 150),
      children: _items(12),
    )));
    expect(
      tester.getSize(find.byType(MerryGoRoundCarousel)).width,
      lessThanOrEqualTo(400),
    );
  });

  testWidgets('mouse wheel rotates and then snaps', (tester) async {
    final controller = MerryGoRoundController();
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      controller: controller,
      children: _items(6),
    )));

    final center = tester.getCenter(find.byKey(const ValueKey('item0')));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(center));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(controller.currentIndex, isNot(0));
    const step = 2 * 3.141592653589793 / 6;
    final r = controller.angle / step;
    expect((r - r.round()).abs(), lessThan(1e-6));
  });

  testWidgets('arrow keys rotate once focused', (tester) async {
    final controller = MerryGoRoundController();
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      controller: controller,
      children: _items(5),
    )));

    // Tapping the front item focuses the carousel without rotating it.
    await tester.tap(find.byKey(const ValueKey('item0')), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 4);
  });

  group('lifecycle and interaction', () {
    testWidgets('zero items builds and ignores navigation', (tester) async {
      final controller = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: controller,
        children: const [],
      )));
      controller.next();
      controller.previous();
      controller.jumpToIndex(3);
      await tester.pumpAndSettle();
      expect(controller.currentIndex, 0);
      expect(controller.isMoving, isFalse);
    });

    testWidgets('one item stays put', (tester) async {
      final controller = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: controller,
        children: _items(1),
      )));
      controller.next();
      await tester.pump();
      expect(controller.isMoving, isFalse);
      expect(controller.currentIndex, 0);
      expect(controller.angle, 0);
    });

    testWidgets('rapid next calls each advance one item', (tester) async {
      final controller = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: controller,
        children: _items(8),
      )));
      controller.next();
      await tester.pump(const Duration(milliseconds: 50));
      controller.next();
      controller.next();
      await tester.pumpAndSettle();
      expect(controller.currentIndex, 3);
    });

    testWidgets('a drag cancels a running animation and queued steps',
        (tester) async {
      final controller = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: controller,
        children: _items(6),
      )));
      controller.next(duration: const Duration(seconds: 1));
      controller.next(duration: const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.drag(
          find.byType(MerryGoRoundCarousel), const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(controller.isMoving, isFalse);
      const step = 2 * 3.141592653589793 / 6;
      final r = controller.angle / step;
      expect((r - r.round()).abs(), lessThan(1e-6));

      // The cancelled steps must not leak into the next one.
      final before = controller.currentIndex;
      controller.next();
      await tester.pumpAndSettle();
      expect(controller.currentIndex, (before + 1) % 6);
    });

    testWidgets('shrinking the list reports the new front item',
        (tester) async {
      final controller = MerryGoRoundController();
      final changes = <int>[];
      Widget build(int n) => _app(MerryGoRoundCarousel(
            controller: controller,
            onIndexChanged: changes.add,
            children: _items(n),
          ));

      await tester.pumpWidget(build(6));
      controller.jumpToIndex(5);
      await tester.pump();
      expect(changes, [5]);

      await tester.pumpWidget(build(3));
      await tester.pump();
      expect(controller.currentIndex, 2);
      expect(changes.last, 2);
    });

    testWidgets('disposing during an animation leaves no timers',
        (tester) async {
      final controller = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: controller,
        autoRotate: true,
        children: _items(5),
      )));
      controller.next();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(controller.hasClients, isFalse);
      // The test framework fails the test if a Timer is still pending.
    });

    testWidgets('auto-rotation pauses and resumes', (tester) async {
      final controller = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: controller,
        autoRotate: true,
        children: _items(6),
      )));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.angle, greaterThan(0));
      expect(controller.isAutoRotating, isTrue);

      controller.pauseAutoRotate();
      final paused = controller.angle;
      await tester.pump(const Duration(seconds: 1));
      expect(controller.angle, paused);
      expect(controller.isAutoRotating, isFalse);

      controller.resumeAutoRotate();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.angle, greaterThan(paused));
    });

    testWidgets('reduced motion jumps instead of animating', (tester) async {
      final controller = MerryGoRoundController();
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: MerryGoRoundCarousel(
                    controller: controller,
                    autoRotate: true,
                    children: _items(5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));

      controller.next();
      expect(controller.currentIndex, 1);
      expect(controller.isMoving, isFalse);

      final angle = controller.angle;
      await tester.pump(const Duration(seconds: 1));
      expect(controller.angle, angle, reason: 'auto-rotate stays off');
    });

    testWidgets('a replaced controller is detached', (tester) async {
      final first = MerryGoRoundController();
      final second = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: first,
        children: _items(5),
      )));
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: second,
        children: _items(5),
      )));
      expect(first.hasClients, isFalse);
      expect(second.hasClients, isTrue);

      second.next();
      await tester.pumpAndSettle();
      expect(second.currentIndex, 1);
    });

    testWidgets('very narrow space does not throw', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 60,
            child: MerryGoRoundCarousel(children: _items(6)),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('onSelectedItemChanged only reports where the wheel stops',
      (tester) async {
    final controller = MerryGoRoundController();
    final passing = <int>[];
    final settled = <int>[];
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      controller: controller,
      onIndexChanged: passing.add,
      onSelectedItemChanged: settled.add,
      children: _items(8),
    )));

    controller.animateToIndex(3);
    await tester.pump(); // starts the animation
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-spin: items passing the front are reported, nothing has settled.
    // (Which items show up depends on frame timing; easeOutCubic can move
    // more than one item between two frames, so don't list them exactly.)
    expect(passing, isNotEmpty);
    expect(settled, isEmpty);

    await tester.pumpAndSettle();
    expect(passing.last, 3);
    expect(settled, [3]);

    controller.animateToIndex(3);
    await tester.pumpAndSettle();
    expect(settled, [3]);
  });

  testWidgets('drag callbacks fire', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      onDragStart: () => events.add('start'),
      onDragEnd: () => events.add('end'),
      children: _items(5),
    )));
    await tester.drag(find.byType(MerryGoRoundCarousel), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(events, ['start', 'end']);
  });

  testWidgets('Enter activates the front item once focused', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      onItemTap: taps.add,
      children: _items(4),
    )));
    await tester.tap(find.byKey(const ValueKey('item0')), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, [0, 0]);
  });

  testWidgets('screen readers get a label, position and adjust actions',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller = MerryGoRoundController();
    await tester.pumpWidget(_app(MerryGoRoundCarousel(
      controller: controller,
      semanticLabel: 'Rides',
      children: _items(5),
    )));

    var node = tester.getSemantics(find.bySemanticsLabel('Rides'));
    expect(node.value, '1 of 5');
    expect(node.increasedValue, '2 of 5');
    expect(node.decreasedValue, '5 of 5');

    node.owner!.performAction(node.id, SemanticsAction.increase);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
    node = tester.getSemantics(find.bySemanticsLabel('Rides'));
    expect(node.value, '2 of 5');
    handle.dispose();
  });

  group('focus outline', () {
    /// The decoration drawn over item [i] for keyboard focus, if any.
    Decoration? outlineOn(int i) {
      final boxes = find.ancestor(
        of: find.byKey(ValueKey('item$i')),
        matching: find.byWidgetPredicate((w) =>
            w is DecoratedBox && w.position == DecorationPosition.foreground),
      );
      final found = boxes.evaluate();
      if (found.isEmpty) return null;
      return (found.single.widget as DecoratedBox).decoration;
    }

    testWidgets('shows on the front item when focused with the keyboard',
        (tester) async {
      await tester.pumpWidget(_app(MerryGoRoundCarousel(children: _items(5))));
      expect(outlineOn(0), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(outlineOn(0), isA<BoxDecoration>());
      for (var i = 1; i < 5; i++) {
        expect(outlineOn(i), isNull);
      }
    });

    testWidgets('follows the front item', (tester) async {
      await tester.pumpWidget(_app(MerryGoRoundCarousel(children: _items(5))));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(outlineOn(0), isNull);
      expect(outlineOn(1), isNotNull);
    });

    testWidgets('is not drawn when focus comes from a tap', (tester) async {
      await tester.pumpWidget(_app(MerryGoRoundCarousel(children: _items(5))));
      await tester.tap(find.byKey(const ValueKey('item0')),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(outlineOn(0), isNull);

      // Pressing a key afterwards switches to keyboard mode and shows it.
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(outlineOn(0), isNotNull);
    });

    testWidgets('is not drawn after a mouse click on desktop', (tester) async {
      await tester.pumpWidget(_app(MerryGoRoundCarousel(children: _items(5))));
      await tester.tap(find.byKey(const ValueKey('item0')),
          kind: PointerDeviceKind.mouse, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(outlineOn(0), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(outlineOn(1), isNotNull);

      // Clicking again hides it until the next key press.
      await tester.tap(find.byKey(const ValueKey('item1')),
          kind: PointerDeviceKind.mouse, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(outlineOn(1), isNull);
    }, variant: TargetPlatformVariant.desktop());

    testWidgets('goes away when focus moves elsewhere', (tester) async {
      final other = FocusNode();
      addTearDown(other.dispose);
      await tester.pumpWidget(_app(Column(children: [
        MerryGoRoundCarousel(children: _items(5)),
        Focus(focusNode: other, child: const SizedBox(height: 10)),
      ])));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(outlineOn(0), isNotNull);

      // requestFocus takes effect in a microtask, after the next frame.
      other.requestFocus();
      await tester.pumpAndSettle();
      expect(outlineOn(0), isNull);
    });

    testWidgets('uses focusDecoration and can be turned off', (tester) async {
      const custom = BoxDecoration(color: Color(0x33FF0000));
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        focusDecoration: custom,
        children: _items(5),
      )));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(outlineOn(0), same(custom));

      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        showFocusHighlight: false,
        children: _items(5),
      )));
      expect(outlineOn(0), isNull);
    });
  });

  group('scroll behavior', () {
    /// A tall page with the carousel near the top, inside a vertical list.
    Widget page(ScrollController scroll, MerryGoRoundController controller,
            MerryGoRoundScrollBehavior behavior) =>
        MaterialApp(
          home: Scaffold(
            body: ListView(controller: scroll, children: [
              SizedBox(
                width: 400,
                child: MerryGoRoundCarousel(
                  controller: controller,
                  scrollBehavior: behavior,
                  children: _items(6),
                ),
              ),
              const SizedBox(height: 2000),
            ]),
          ),
        );

    Future<void> scrollOverCarousel(WidgetTester tester, Offset delta) async {
      final center = tester.getCenter(find.byKey(const ValueKey('item0')));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(center));
      await tester.sendEventToBinding(pointer.scroll(delta));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
    }

    testWidgets('always: a vertical wheel turns the carousel, not the page',
        (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final controller = MerryGoRoundController();
      await tester.pumpWidget(
          page(scroll, controller, MerryGoRoundScrollBehavior.always));
      await scrollOverCarousel(tester, const Offset(0, 300));
      expect(controller.currentIndex, isNot(0));
      expect(scroll.offset, 0);
    });

    testWidgets('horizontalOnly: vertical scrolls the page', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final controller = MerryGoRoundController();
      await tester.pumpWidget(
          page(scroll, controller, MerryGoRoundScrollBehavior.horizontalOnly));

      await scrollOverCarousel(tester, const Offset(0, 100));
      expect(scroll.offset, 100);
      expect(controller.currentIndex, 0);

      scroll.jumpTo(0);
      await tester.pump();
      await scrollOverCarousel(tester, const Offset(300, 0));
      expect(controller.currentIndex, isNot(0));
      expect(scroll.offset, 0);
    });

    testWidgets('next() right after a scroll is not undone by the scroll snap',
        (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final controller = MerryGoRoundController();
      await tester.pumpWidget(
          page(scroll, controller, MerryGoRoundScrollBehavior.always));

      // A small scroll that snaps back to item 0 when left alone.
      final center = tester.getCenter(find.byKey(const ValueKey('item0')));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(center));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 5)));
      await tester.pump();

      // Within the 150 ms scroll-end window.
      controller.next();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(controller.currentIndex, 1);
    });

    testWidgets('horizontalOnly: Shift + wheel turns the carousel',
        (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final controller = MerryGoRoundController();
      await tester.pumpWidget(
          page(scroll, controller, MerryGoRoundScrollBehavior.horizontalOnly));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await scrollOverCarousel(tester, const Offset(0, 300));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(controller.currentIndex, isNot(0));
      expect(scroll.offset, 0);
    });

    testWidgets('whenFocused: only after the carousel takes focus',
        (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final controller = MerryGoRoundController();
      await tester.pumpWidget(
          page(scroll, controller, MerryGoRoundScrollBehavior.whenFocused));

      await scrollOverCarousel(tester, const Offset(0, 100));
      expect(controller.currentIndex, 0);
      expect(scroll.offset, 100);

      scroll.jumpTo(0);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('item0')),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      await scrollOverCarousel(tester, const Offset(0, 300));
      expect(controller.currentIndex, isNot(0));
      expect(scroll.offset, 0);
    });

    testWidgets('never: the page always scrolls', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final controller = MerryGoRoundController();
      await tester.pumpWidget(
          page(scroll, controller, MerryGoRoundScrollBehavior.never));
      await scrollOverCarousel(tester, const Offset(0, 100));
      expect(controller.currentIndex, 0);
      expect(scroll.offset, 100);
    });

    testWidgets('deprecated enableScrollWheel: false still turns it off',
        (tester) async {
      final controller = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: controller,
        // ignore: deprecated_member_use_from_same_package
        enableScrollWheel: false,
        children: _items(6),
      )));
      await scrollOverCarousel(tester, const Offset(0, 300));
      expect(controller.currentIndex, 0);
    });

    testWidgets('scrollWheelSensitivity scales wheel turns only',
        (tester) async {
      final slow = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        controller: slow,
        snapToItem: false,
        scrollWheelSensitivity: 0.5,
        children: _items(6),
      )));
      await scrollOverCarousel(tester, const Offset(0, 40));
      final slowAngle = slow.angle;

      final normal = MerryGoRoundController();
      await tester.pumpWidget(_app(MerryGoRoundCarousel(
        key: const ValueKey('normal'),
        controller: normal,
        snapToItem: false,
        children: _items(6),
      )));
      await scrollOverCarousel(tester, const Offset(0, 40));
      expect(slowAngle, closeTo(normal.angle / 2, 1e-9));
    });
  });

  testWidgets('each frame builds every item once', (tester) async {
    // Benchmark baseline: the per-frame cost is n itemBuilder calls, so at
    // 60 fps the wheel makes n × 60 calls a second while it moves.
    const n = 8;
    var calls = 0;
    await tester.pumpWidget(_app(MerryGoRoundCarousel.builder(
      itemCount: n,
      autoRotate: true,
      itemBuilder: (context, index, depth) {
        calls++;
        return const SizedBox();
      },
    )));
    await tester.pump(const Duration(milliseconds: 16));
    calls = 0;
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(calls, n * 10);
  });

  test('constructors validate their arguments', () {
    expect(() => MerryGoRoundCarousel(dragSensitivity: 0, children: const []),
        throwsAssertionError);
    expect(() => MerryGoRoundCarousel(radius: -1, children: const []),
        throwsAssertionError);
    expect(() => MerryGoRoundCarousel(initialIndex: -1, children: const []),
        throwsAssertionError);
    expect(
      () => MerryGoRoundCarousel.builder(
        itemCount: 3,
        itemBuilder: (context, index, depth) => const SizedBox(),
        friction: 1,
      ),
      throwsAssertionError,
    );
    expect(
      () => MerryGoRoundCarousel(
        // ignore: deprecated_member_use_from_same_package
        enableScrollWheel: false,
        scrollBehavior: MerryGoRoundScrollBehavior.horizontalOnly,
        children: const [],
      ),
      throwsAssertionError,
    );
    expect(
        () =>
            MerryGoRoundCarousel(scrollWheelSensitivity: 0, children: const []),
        throwsAssertionError);
  });
}
