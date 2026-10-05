/// Utilitas format bobot badan bayi ke standar gram klinis
/// Mengikuti prinsip YAGNI & Ponytail (bebas dependensi eksternal, murni Dart stdlib)
class WeightFormatter {
  WeightFormatter._();

  /// Konversi dari kg (Float database) ke tampilan gram (misal: 3.45 -> "3.450 gram")
  static String formatKgToGrams(num? weightKg, {bool appendUnit = true}) {
    if (weightKg == null || weightKg <= 0) return '-';
    final grams = (weightKg * 1000).round();
    return formatGrams(grams, appendUnit: appendUnit);
  }

  /// Format integer gram dengan separator ribuan titik (misal: 3200 -> "3.200 gram")
  static String formatGrams(int? grams, {bool appendUnit = true}) {
    if (grams == null || grams <= 0) return '-';
    final formatted = grams.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return appendUnit ? '$formatted gram' : formatted;
  }

  /// Parser dari input gram di formulir ke kilogram untuk payload API
  /// Menerima "3450", "3.450", atau "3,450" -> menghasilkan double 3.45
  static double? parseGramsInputToKg(String raw) {
    final clean = raw.trim().replaceAll('.', '').replaceAll(',', '');
    final grams = double.tryParse(clean);
    if (grams == null || grams <= 0) return null;
    return grams / 1000.0;
  }
}
