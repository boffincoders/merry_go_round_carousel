// Frame-timing benchmarks for MerryGoRoundCarousel.
//
// Run in profile mode on a real device (debug builds and simulators give
// numbers that mean nothing):
//
//   cd example
//   flutter drive --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/carousel_perf_test.dart
//
// Add `--dart-define=PERF_QUICK=true` for a short run (fewer item counts,
// 2 s instead of 10 s of auto-rotation) that only checks the setup works.
//
// Results go to build/carousel_perf/: one JSON file per run and a
// summary.md table.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:merry_go_round_carousel/merry_go_round_carousel.dart';

const bool quick = bool.fromEnvironment('PERF_QUICK');
const List<int> itemCounts = quick ? [5, 12] : [5, 8, 12, 20];
const Duration autoRotateTime = Duration(seconds: quick ? 2 : 10);
const Size itemSize = Size(120, 160);

/// The kinds of card measured.
enum Card {
  /// Coloured box with an icon and text.
  simple,

  /// Image card: decoded image, rounded corners, shadow and caption.
  image,

  /// [image] with `addRepaintBoundaries: false`, for comparison.
  imageNoBoundaries,
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Let the engine schedule frames as it would in an app, so the timings are
  // real frame timings rather than test pumps.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // Images are drawn in memory instead of loaded from the network, so network
  // speed doesn't skew the results.
  late final List<Uint8List> images;
  setUpAll(() async => images = await _makeImages(6));

  Future<void> run(
    WidgetTester tester,
    String name,
    Card card,
    int count,
    Future<void> Function(MerryGoRoundController controller) action, {
    bool autoRotate = false,
  }) async {
    final controller = MerryGoRoundController();
    await tester.pumpWidget(_BenchApp(
      controller: controller,
      card: card,
      count: count,
      images: images,
      autoRotate: autoRotate,
    ));
    // Let images decode and the first frames settle before measuring.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    await binding.watchPerformance(
      () => action(controller),
      reportKey: '${name}_${card.name}_$count',
    );

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }

  for (final card in Card.values) {
    for (final count in itemCounts) {
      testWidgets('auto-rotate, ${card.name}, $count items', (tester) async {
        await run(tester, 'autorotate', card, count, autoRotate: true,
            (_) async {
          await Future<void>.delayed(autoRotateTime);
        });
      });

      testWidgets('10 flings, ${card.name}, $count items', (tester) async {
        await run(tester, 'fling', card, count, (_) async {
          final wheel = find.byType(MerryGoRoundCarousel);
          for (var i = 0; i < 10; i++) {
            await tester.fling(wheel, Offset(i.isEven ? -300 : 300, 0), 1500);
            await tester.pumpAndSettle();
          }
        });
      });

      testWidgets('20 rapid next(), ${card.name}, $count items',
          (tester) async {
        await run(tester, 'next', card, count, (controller) async {
          final steps = <Future<void>>[];
          for (var i = 0; i < 20; i++) {
            steps.add(controller.next());
            await Future<void>.delayed(const Duration(milliseconds: 60));
          }
          await Future.wait(steps);
          await tester.pumpAndSettle();
        });
      });
    }
  }
}

class _BenchApp extends StatelessWidget {
  const _BenchApp({
    required this.controller,
    required this.card,
    required this.count,
    required this.images,
    required this.autoRotate,
  });

  final MerryGoRoundController controller;
  final Card card;
  final int count;
  final List<Uint8List> images;
  final bool autoRotate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: MerryGoRoundCarousel.builder(
            controller: controller,
            itemCount: count,
            itemSize: itemSize,
            autoRotate: autoRotate,
            autoRotateSpeed: 0.8,
            addRepaintBoundaries: card != Card.imageNoBoundaries,
            itemBuilder: (context, index, depth) => card == Card.simple
                ? _SimpleCard(index: index)
                : _ImageCard(
                    index: index, bytes: images[index % images.length]),
          ),
        ),
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.primaries[index % Colors.primaries.length],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 36),
          const SizedBox(height: 8),
          Text('Item $index', style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.index, required this.bytes});
  final int index;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(0, 4), color: Colors.black38),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: Colors.black54,
                padding: const EdgeInsets.all(6),
                child: Text(
                  'Destination $index',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws [count] photo-sized PNGs (gradients and circles) in memory.
Future<List<Uint8List>> _makeImages(int count) async {
  final result = <Uint8List>[];
  for (var i = 0; i < count; i++) {
    const w = 480.0, h = 640.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final colors = [
      Colors.primaries[i * 3 % Colors.primaries.length],
      Colors.primaries[(i * 3 + 5) % Colors.primaries.length],
    ];
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, const Offset(w, h), colors),
    );
    for (var c = 0; c < 12; c++) {
      canvas.drawCircle(
        Offset((c * 97 + i * 41) % w, (c * 151 + i * 67) % h),
        30 + (c * 13 % 60),
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );
    }
    final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    result.add(data!.buffer.asUint8List());
  }
  return result;
}
