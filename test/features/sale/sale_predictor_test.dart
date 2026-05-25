import 'package:flutter_test/flutter_test.dart';
import 'package:sale_tracker/features/sale/domain/sale.dart';
import 'package:sale_tracker/features/sale/domain/sale_predictor.dart';

Sale _sale(int year, int month, int day) => Sale(
      id: year * 10000 + month * 100 + day,
      startAt: DateTime.utc(year, month, day),
      endAt: DateTime.utc(year, month, day + 1),
      title: 'sale',
      detectedAt: DateTime.utc(year, month, day),
    );

void main() {
  final predictor = SalePredictor();

  test('returns null when fewer than 2 sales', () {
    expect(predictor.predict([]), isNull);
    expect(predictor.predict([_sale(2026, 1, 1)]), isNull);
  });

  test('uses median gap and bases prediction on the last sale', () {
    // Gaps: 7d, 7d, 14d -> median 7d. Last start = 2026-01-29.
    final history = [
      _sale(2026, 1, 1),
      _sale(2026, 1, 8),
      _sale(2026, 1, 15),
      _sale(2026, 1, 29),
    ];
    final pred = predictor.predict(history)!;
    expect(pred.sampleSize, 3);
    expect(pred.expectedStart, DateTime.utc(2026, 2, 5));
  });

  test('median is robust to a single outlier', () {
    // Gaps: 7d, 7d, 60d -> median 7d, mean would be ~25d.
    final history = [
      _sale(2026, 1, 1),
      _sale(2026, 1, 8),
      _sale(2026, 1, 15),
      _sale(2026, 3, 16),
    ];
    final pred = predictor.predict(history)!;
    expect(pred.expectedStart, DateTime.utc(2026, 3, 23));
  });
}
