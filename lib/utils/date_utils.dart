/// Small helpers to convert dates and times to and from the TEXT format
/// stored in SQLite.
class AppDateUtils {
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// DateTime -> "2026-11-05"
  static String formatDate(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// "2026-11-05" -> DateTime (midnight)
  static DateTime parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  /// hour/minute -> "09:30"
  static String formatTime(int hour, int minute) =>
      '${_two(hour)}:${_two(minute)}';

  /// "09:30" -> [9, 30]
  static List<int> parseTime(String s) {
    final p = s.split(':');
    return [int.parse(p[0]), int.parse(p[1])];
  }

  /// True if both dates fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}