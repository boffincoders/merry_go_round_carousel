// Host side of the carousel benchmarks; see
// integration_test/carousel_perf_test.dart for how to run them.
//
// Writes each run's frame timing summary to build/carousel_perf/<run>.json
// and a table of all runs to build/carousel_perf/summary.md.

import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

const _dir = 'build/carousel_perf';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null || data.isEmpty) return;
      final runs = <String, Map<String, dynamic>>{};
      for (final entry in data.entries) {
        final summary = Map<String, dynamic>.from(entry.value as Map);
        runs[entry.key] = summary;
        await writeResponseData(
          summary,
          testOutputFilename: entry.key,
          destinationDirectory: _dir,
        );
      }
      final file = File('$_dir/summary.md');
      await file.writeAsString(_table(runs));
      stdout.writeln('Benchmark summary written to ${file.path}');
    },
  );
}

String _table(Map<String, Map<String, dynamic>> runs) {
  String ms(Map<String, dynamic> s, String key) {
    final v = s[key];
    return v is num ? v.toStringAsFixed(2) : '–';
  }

  String n(Map<String, dynamic> s, String key) => '${s[key] ?? '–'}';

  final out = StringBuffer()
    ..writeln('# Carousel benchmark run')
    ..writeln()
    ..writeln('Date: ${DateTime.now().toIso8601String()}  ')
    ..writeln('Fill in: device, OS, Flutter version, build mode.')
    ..writeln()
    ..writeln('Times in ms. "Missed" = frames over the 16.7 ms (60 Hz) budget.')
    ..writeln()
    ..writeln('| Run | Frames | Build avg | Build p90 | Build p99 | '
        'Build missed | Raster avg | Raster p90 | Raster p99 | '
        'Raster missed |')
    ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
  final keys = runs.keys.toList()..sort(_byScenarioCardCount);
  for (final key in keys) {
    final s = runs[key]!;
    out.writeln('| $key '
        '| ${n(s, 'frame_count')} '
        '| ${ms(s, 'average_frame_build_time_millis')} '
        '| ${ms(s, '90th_percentile_frame_build_time_millis')} '
        '| ${ms(s, '99th_percentile_frame_build_time_millis')} '
        '| ${n(s, 'missed_frame_build_budget_count')} '
        '| ${ms(s, 'average_frame_rasterizer_time_millis')} '
        '| ${ms(s, '90th_percentile_frame_rasterizer_time_millis')} '
        '| ${ms(s, '99th_percentile_frame_rasterizer_time_millis')} '
        '| ${n(s, 'missed_frame_rasterizer_budget_count')} |');
  }
  return out.toString();
}

/// Sorts "fling_image_12" by scenario, then card, then item count as a
/// number (so 5 comes before 12).
int _byScenarioCardCount(String a, String b) {
  final pa = a.split('_'), pb = b.split('_');
  for (var i = 0; i < 2; i++) {
    final c = pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return int.parse(pa.last).compareTo(int.parse(pb.last));
}
