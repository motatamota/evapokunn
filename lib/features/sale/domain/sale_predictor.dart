import 'dart:math' as math;

import 'sale.dart';

class PredictionResult {
  final DateTime expectedStart;
  final Duration uncertainty;
  final int sampleSize;

  const PredictionResult({
    required this.expectedStart,
    required this.uncertainty,
    required this.sampleSize,
  });
}

/// Predicts the next sale start time using the median gap between
/// historical sale starts (median is robust to outliers).
class SalePredictor {
  /// Returns null when there's not enough data (need >= 2 starts).
  PredictionResult? predict(List<Sale> history) {
    if (history.length < 2) return null;
    final sorted = [...history]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final gaps = <Duration>[];
    for (var i = 1; i < sorted.length; i++) {
      gaps.add(sorted[i].startAt.difference(sorted[i - 1].startAt));
    }
    final median = _medianDuration(gaps);
    final stdev = _stdevDuration(gaps, median);
    final last = sorted.last.startAt;
    return PredictionResult(
      expectedStart: last.add(median),
      uncertainty: stdev,
      sampleSize: gaps.length,
    );
  }

  Duration _medianDuration(List<Duration> values) {
    final ms = values.map((d) => d.inMilliseconds).toList()..sort();
    final mid = ms.length ~/ 2;
    final medianMs = ms.length.isOdd
        ? ms[mid]
        : ((ms[mid - 1] + ms[mid]) / 2).round();
    return Duration(milliseconds: medianMs);
  }

  Duration _stdevDuration(List<Duration> values, Duration mean) {
    if (values.length < 2) return Duration.zero;
    final meanMs = mean.inMilliseconds.toDouble();
    final variance = values
            .map((d) => math.pow(d.inMilliseconds - meanMs, 2).toDouble())
            .reduce((a, b) => a + b) /
        (values.length - 1);
    return Duration(milliseconds: math.sqrt(variance).round());
  }
}
