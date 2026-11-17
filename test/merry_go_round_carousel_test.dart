import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
}
