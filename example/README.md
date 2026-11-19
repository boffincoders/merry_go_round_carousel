# merry_go_round_carousel example

Demo app for `merry_go_round_carousel`.

```
flutter create .   # generates the platform folders
flutter run
```

The app opens on the **Basic** page. Tap **From server** in the app bar for the
second page, which loads its options from a mock API.

## Benchmarks

`integration_test/carousel_perf_test.dart` measures frame build and raster
times for three scenarios (10 s of auto-rotation, 10 flings, 20 quick
`next()` calls) with 5, 8, 12 and 20 items and three kinds of card: simple
cards, image cards, and image cards without repaint boundaries.

Run it in **profile mode on a real device**. Debug builds and simulators give
numbers that mean nothing.

```
flutter drive --profile \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/carousel_perf_test.dart
```

For Chrome on desktop, add `-d chrome` (needs `chromedriver` running on port
4444). Add `--dart-define=PERF_QUICK=true` for a short run that only checks
the setup works.

Results are written to `build/carousel_perf/`: one JSON file per run and a
`summary.md` table (average, 90th and 99th percentile build and raster times,
and frames over the 16.7 ms budget). Add the device, OS and Flutter version
before sharing it.
