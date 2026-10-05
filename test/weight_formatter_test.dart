import 'package:flutter_test/flutter_test.dart';
import 'package:generasi_emas/core/weight_formatter.dart';

void main() {
  group('WeightFormatter', () {
    test('formatKgToGrams formats kilograms to grams string', () {
      expect(WeightFormatter.formatKgToGrams(3.45), '3.450 gram');
      expect(WeightFormatter.formatKgToGrams(3.8), '3.800 gram');
      expect(WeightFormatter.formatKgToGrams(0.75), '750 gram');
      expect(WeightFormatter.formatKgToGrams(null), '-');
      expect(WeightFormatter.formatKgToGrams(0), '-');
      expect(WeightFormatter.formatKgToGrams(3.45, appendUnit: false), '3.450');
    });

    test('formatGrams formats grams integer with thousands dot separator', () {
      expect(WeightFormatter.formatGrams(3200), '3.200 gram');
      expect(WeightFormatter.formatGrams(950), '950 gram');
      expect(WeightFormatter.formatGrams(12500), '12.500 gram');
      expect(WeightFormatter.formatGrams(null), '-');
      expect(WeightFormatter.formatGrams(0), '-');
      expect(WeightFormatter.formatGrams(-100), '-');
      expect(WeightFormatter.formatGrams(3200, appendUnit: false), '3.200');
    });

    test('parseGramsInputToKg parses various user inputs into kilograms', () {
      expect(WeightFormatter.parseGramsInputToKg('3450'), 3.45);
      expect(WeightFormatter.parseGramsInputToKg('3.450'), 3.45);
      expect(WeightFormatter.parseGramsInputToKg(' 3450 '), 3.45);
      expect(WeightFormatter.parseGramsInputToKg(''), null);
      expect(WeightFormatter.parseGramsInputToKg('abc'), null);
      expect(WeightFormatter.parseGramsInputToKg('-500'), null);
    });
  });
}
