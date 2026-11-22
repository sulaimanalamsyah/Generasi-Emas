import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:generasi_emas/core/date_formatter.dart';
import 'package:generasi_emas/core/maternal_guide_data.dart';
import 'package:generasi_emas/core/weight_formatter.dart';
import 'package:generasi_emas/widgets/common.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

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

  group('ENICare clinical helpers', () {
    test('formatNurseDisplayName honors salutation, default Ns., and Tanpa Gelar', () {
      expect(formatNurseDisplayName('Siti Aminah', null), 'Ns. Siti Aminah');
      expect(formatNurseDisplayName('Siti Aminah', 'Ns.'), 'Ns. Siti Aminah');
      expect(formatNurseDisplayName('Budi Santoso', 'Dr.'), 'Dr. Budi Santoso');
      expect(formatNurseDisplayName('Rina', 'Bd.'), 'Bd. Rina');
      expect(formatNurseDisplayName('Rina', ''), 'Rina');
      expect(formatNurseDisplayName('Ns. Siti Aminah', 'Ns.'), 'Ns. Siti Aminah');
      expect(formatNurseDisplayName('', 'Ns.'), 'Perawat');
    });

    test('AppDateFormatter formats scores cleanly without trailing .0', () {
      expect(AppDateFormatter.score(null), '-');
      expect(AppDateFormatter.score(80), '80');
      expect(AppDateFormatter.score(80.0), '80');
      expect(AppDateFormatter.score(82.5), '82.5');
      expect(AppDateFormatter.score('90.0'), '90');
    });

    test('activeMaternalGuideSlot matches daytime and overnight WIB intervals', () {
      expect(kDefaultMaternalGuideSlots.length, 14);
      final afternoonUtc = DateTime.utc(2026, 11, 22, 6, 30); // 13:30 WIB
      expect(activeMaternalGuideSlot(kDefaultMaternalGuideSlots, afternoonUtc)?['id'], 'slot_13_14');
      final overnightUtc = DateTime.utc(2026, 11, 22, 16, 0); // 23:00 WIB
      expect(activeMaternalGuideSlot(kDefaultMaternalGuideSlots, overnightUtc)?['id'], 'slot_21_06');
    });

    test('isSameLibraryItem prefers ID and falls back to title+url together', () {
      expect(
        isSameLibraryItem(
          currentId: '10',
          currentTitle: 'Video A',
          currentUrl: 'https://example.com/shared',
          candidate: {'id': 10, 'title': 'Video A', 'url': 'https://example.com/shared'},
        ),
        isTrue,
      );
      expect(
        isSameLibraryItem(
          currentId: '10',
          currentTitle: 'Video A',
          currentUrl: 'https://example.com/shared',
          candidate: {'id': 11, 'title': 'Video B', 'url': 'https://example.com/shared'},
        ),
        isFalse,
      );
      expect(
        isSameLibraryItem(
          currentTitle: 'Video A',
          currentUrl: 'https://example.com/shared',
          candidate: {'title': 'Video B', 'url': 'https://example.com/shared'},
        ),
        isFalse,
      );
    });
  });
}
