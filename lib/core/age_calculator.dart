/// Utilitas Perhitungan Usia Kronologis Bayi (Standar Klinis Pediatrik)
/// Mendukung format neonatus (< 30 hari), bayi/baduta (1-24 bulan), dan balita.
class InfantAge {
  final int totalDays;
  final double monthsFraction;
  final String formatted; // Contoh: "8 Bulan 10 Hari" atau "3 Minggu 2 Hari"
  final String shortFormatted; // Contoh: "8 Bln" atau "3 Mgg"
  final int months;
  final int days;

  const InfantAge({
    required this.totalDays,
    required this.monthsFraction,
    required this.formatted,
    required this.shortFormatted,
    required this.months,
    required this.days,
  });

  /// Menghitung usia bayi dari tanggal lahir (birthDate) terhadap tanggal acuan (targetDate/hari ini).
  static InfantAge calculate(DateTime birthDate, [DateTime? targetDate]) {
    final refRaw = targetDate ?? DateTime.now();
    // Normalisasi ke tanggal kalender murni (tahun, bulan, hari) untuk mencegah selisih jam
    final b = birthDate.isUtc ? birthDate.toLocal() : birthDate;
    final r = refRaw.isUtc ? refRaw.toLocal() : refRaw;
    final birth = DateTime(b.year, b.month, b.day);
    final ref = DateTime(r.year, r.month, r.day);
    final totalDays = ref.difference(birth).inDays;

    if (totalDays <= 0) {
      return const InfantAge(
        totalDays: 0,
        monthsFraction: 0.0,
        formatted: 'Baru lahir (< 1 Hari)',
        shortFormatted: '0 Hari',
        months: 0,
        days: 0,
      );
    }

    // Fase Neonatus (< 30 Hari) -> Format Minggu & Hari
    if (totalDays < 30) {
      final weeks = totalDays ~/ 7;
      final remDays = totalDays % 7;
      String text;
      String shortText;
      if (weeks > 0 && remDays > 0) {
        text = '$weeks Minggu $remDays Hari';
        shortText = '$weeks Mgg $remDays Hr';
      } else if (weeks > 0) {
        text = '$weeks Minggu';
        shortText = '$weeks Mgg';
      } else {
        text = '$remDays Hari';
        shortText = '$remDays Hr';
      }

      return InfantAge(
        totalDays: totalDays,
        monthsFraction: (totalDays / 30.4375 * 10).round() / 10,
        formatted: text,
        shortFormatted: shortText,
        months: 0,
        days: totalDays,
      );
    }

    // Fase Bayi & Anak (>= 30 Hari)
    int months = (ref.year - birth.year) * 12 + (ref.month - birth.month);
    int days = ref.day - birth.day;

    if (days < 0) {
      months -= 1;
      // Ambil jumlah hari di bulan sebelumnya
      final prevMonthLastDay = DateTime(ref.year, ref.month, 0).day;
      days += prevMonthLastDay;
    }

    final fraction = (totalDays / 30.4375 * 10).round() / 10;

    String text;
    if (months >= 24) {
      final years = months ~/ 12;
      final remMonths = months % 12;
      text = remMonths > 0 ? '$years Tahun $remMonths Bulan' : '$years Tahun';
    } else {
      text = days > 0 ? '$months Bulan $days Hari' : '$months Bulan';
    }

    return InfantAge(
      totalDays: totalDays,
      monthsFraction: fraction,
      formatted: text,
      shortFormatted: '$months Bln',
      months: months,
      days: days,
    );
  }
}

