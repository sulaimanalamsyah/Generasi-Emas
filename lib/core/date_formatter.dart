import 'package:intl/intl.dart';

/// Shared Indonesian date & score formatting utilities for ENICare.
class AppDateFormatter {
  AppDateFormatter._();

  static DateTime? tryParseLocal(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    final dt = DateTime.tryParse(raw.toString().trim());
    return dt?.toLocal();
  }

  /// Formats timestamp as `dd/MM/yyyy HH:mm` (or `'-'` if invalid).
  static String dateTime(dynamic raw) {
    final dt = tryParseLocal(raw);
    if (dt == null) return raw == null ? '-' : raw.toString();
    return DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(dt);
  }

  /// Formats date as `dd MMM yyyy` (e.g. `20 Feb 2026`).
  static String shortDate(dynamic raw) {
    final dt = tryParseLocal(raw);
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
  }

  /// Formats date as `EEEE, dd MMMM yyyy`.
  static String fullDate(dynamic raw) {
    final dt = tryParseLocal(raw);
    if (dt == null) return '-';
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(dt);
  }

  /// Formats numeric score cleanly without trailing `.0`.
  static String score(dynamic raw) {
    if (raw == null) return '-';
    if (raw is num) {
      return raw % 1 == 0 ? raw.toInt().toString() : raw.toStringAsFixed(1);
    }
    final parsed = num.tryParse(raw.toString().trim());
    if (parsed == null) return raw.toString();
    return parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toStringAsFixed(1);
  }
}
